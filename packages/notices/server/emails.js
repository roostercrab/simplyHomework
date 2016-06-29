/* global Kadira, Grades, Projects, updateGrades, SyncedCron, Classes,
   GradeFunctions, Analytics */

import emails from 'meteor/emails'
import { functions } from 'meteor/simply:external-services-connector'
import moment from 'moment-timezone'
moment.locale('nl')

// TODO: have a central place for the default options of notifications, just
// like the 'privacy' package has. Currently if we want to change the default of
// notifications options we have to do that on various places. Would be nice if
// it would just be one.

/**
 * @method sendEmail
 * @param {String} userId
 * @param {String} subject
 * @param {String} html
 */
function sendEmail (userId, subject, html) {
	Email.send({
		from: 'simplyHomework <hello@simplyApps.nl>',
		to: getUserField(userId, 'emails[0].address'),
		subject: `simplyHomework | ${subject}`,
		html,
	})
}

SyncedCron.add({
	name: 'Notify new grades',
	schedule: (parser) => parser.recur().every(1).hour(),
	job: function () {
		const toString = (g) => g.toString().replace('.', ',')

		const users = Meteor.users.find({
			'profile.firstName': { $ne: '' },
			'settings.notifications.email.newGrade': { $ne: false },
		}).fetch()

		users.forEach((user) => {
			const userId = user._id

			functions.updateGrades(userId, false)

			const grades = Grades.find({
				ownerId: userId,
				isEnd: false,
				classId: { $exists: true },
				$and: [
					{ dateFilledIn: { $gte: Date.today().addDays(-1) }},
					// user probably has already seen the grade when he logged in on
					// simplyHomework, no need to send a mail.
					{ dateFilledIn: { $gt: user.status.lastLogin.date }},
				]
			}, {
				fields: {
					_id: 1,
					classId: 1,
					dateFilledIn: 1,
					gradeStr: 1,
					passed: 1,
					ownerId: 1,
				},
			})

			grades.forEach((grade) => {
				const c = Classes.findOne(grade.classId)

				try {
					const html = Promise.await(emails.cijfer({
						className: c.name,
						classUrl: Meteor.absoluteUrl(`class/${c._id}`),
						grade: toString(grade),
						passed: grade.passed,
						average: toString(GradeFunctions.getEndGrade(c._id, userId)),
					}))
					sendEmail(userId, `Nieuw cijfer voor ${c.name}`, html)
					Analytics.insert({
						type: 'send-mail',
						date: new Date,
						emailType: 'grade',
					})
				} catch (err) {
					Kadira.trackError(
						'notices-emails',
						err.message,
						{ stacks: err.stack }
					)
				}
			})
		})
	},
})

SyncedCron.add({
	name: 'Notify new messages',
	schedule: (parser) => parser.recur().every(1).hour(),
	job: function () {
		// TODO: handle replies

		const users = Meteor.users.find({
			'profile.firstName': { $ne: '' },
			'settings.notifications.email.newGrade': { $ne: false },

			// REVIEW: I have commented this out since I'm not really sure why
			// this was here in the first place, maybe I had a good reason for
			// it, or maybe it was just pure shit to begin with.
			// (We could also just check if the person is idle or offline, maybe
			// that's better.)
			// 'status.online': false,
		}).fetch()
		let notifiedCount = 0

		users.forEach((user) => {
			const userId = user._id

			functions.updateMessages(userId, 0, [ 'inbox' ])

			const messages = Messages.find({
				fetchedFor: userId,
				isRead: false,
				sendDate: { $gt: user.status.lastLogin.date },
				notifiedOn: null,
			}, {
				fields: {
					_id: 1,
					fetchedFor: 1,
					isRead: 1,
					sendDate: 1,
					notifiedOn: 1,

					attachmentIds: 1,
					body: 1,
					sender: 1,
					recipients: 1,
					subject: 1,
				},
			})

			messages.forEach((message) => {
				try {
					// TODO: when we have better support for hotlinking inside
					// of the router for file paths,
					// (see ../../external-services-connector/server/router.coffee)
					// we should add hotlinks to the attachments inside of the
					// message body.

					const lines = []
					const pushKeyVal = (key, val) => lines.push(`<b>${key}</b>: ${val}`)

					pushKeyVal('Van', message.sender.fullName)
					pushKeyVal('Verzonden om', moment(message.sendDate).tz('Europe/Amsterdam').format('dddd D MMMM YYYY HH:mm'))
					pushKeyVal('Aan', message.recipientsString(Infinity, false))
					pushKeyVal('Onderwerp', message.subject)
					if (message.attachmentIds.length > 0) {
						const plural = (count, singular, plural) => count === 1 ? singular : plural
						const key = plural(message.attachmentIds.length, 'Bijlage', 'Bijlages')
						const val = message.attachments().map((f) => `<a href="${f.url()}/${userId}">${f.name}</a>`).join(', ')
						pushKeyVal(key, val)
					}
					lines.push('\n' + message.body)

					sendMail(user, `Bericht van ${message.sender.fullName}`, lines.join('\n'))

					notifiedCount++
					Analytics.insert({
						type: 'send-mail',
						date: new Date,
						emailType: 'message',
					})
					Messages.update(message._id, {
						$set: {
							notifiedOn: new Date(),
						},
					})
				} catch (err) {
					Kadira.trackError(
						'notices-emails',
						err.message,
						{ stacks: err.stack }
					)
				}
			})
		})

		const str = `notified ${notifiedCount} new message(s) per mail.`
		console.log(str)
		return str
	},
})

NoticeMails = {
	projects(projectId, addedUserId, adderUserId) {
		const setting = getUserField(
			addedUserId,
			'settings.notifications.email.joinedProject',
			true
		)
		if (!setting) {
			return
		}

		const project = Projects.findOne(projectId)
		const adder = Meteor.users.findOne(adderUserId)
		try {
			const html = Promise.await(emails.project({
				projectName: project.name,
				projectUrl: Meteor.absoluteUrl(`project/${projectId}`),
				personName: `${adder.profile.firstName} ${adder.profile.lastName}`,
			}))
			sendEmail(addedUserId, 'Toegevoegd aan project', html)
			Analytics.insert({
				type: 'send-mail',
				date: new Date,
				emailType: 'project',
			})
		} catch (err) {
			Kadira.trackError(
				'notices-emails',
				err.message,
				{ stacks: err.stack }
			)
		}
	}
}
