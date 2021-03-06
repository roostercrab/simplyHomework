chroma = require 'chroma-js'

noticeBanner = new ReactiveVar
searchRes = new ReactiveVar undefined

classId = -> FlowRouter.getParam 'id'
currentClass = -> Classes.findOne classId()
getNextTest = ->
	CalendarItems.findOne
		'userIds': Meteor.userId()
		'classId': classId()
		'content': $exists: yes
		'content.type': $in: [ 'test', 'exam', 'quiz', 'oral' ]
		'content.description': $exists: yes
		'startDate': $gt: new Date
		'scrapped': no
getChatRoom = ->
	id = classId()
	ChatRooms.findOne
		type: 'class'
		'classInfo.ids': id

Template.classView.helpers
	class: -> currentClass()
	classBorderColor: -> chroma(@__color).darken().hex()

	noticeBanner: ->
		banner = noticeBanner.get()
		if banner?
			_.extend banner,
				__clickable: if banner.onClick? then 'clickable' else ''

	searchPlaceholder: ->
		_.sample [
			'Woordenlijsten H1'
			'Boekverslag gouden ei'
			'Samenvatting hoofdstuk 5'
		]

	endGrade: -> GradeFunctions.getEndGrade @_id, Meteor.userId()

	hoursPerWeek: ->
		CalendarItems.find(
			userIds: Meteor.userId()
			classId: classId()
			startDate: $gte: Date.today()
			endDate: $lte: Date.today().addDays 7
		).count()
	nextTestString: ->
		test = getNextTest()
		if test?
			minuteTracker.depend()
			moment(test.startDate).fromNow yes
		else
			'geen'
	projectCount: ->
		Projects.find(
			classId: classId()
			participants: Meteor.userId()
			finished: no
		).count()

	chatRoom: getChatRoom

	lastChatMessage: ->
		chatRoom = getChatRoom()
		if chatRoom?
			ChatMessages.findOne {
				chatRoomId: chatRoom._id
			}, {
				sort:
					time: -1
			}

	chatPersons: ->
		Meteor.users.find {
			_id: $in: getChatRoom()?.users ? []
		}, {
			sort:
				'profile.firstName': 1
		}

Template.classView.onCreated ->
	@autorun =>
		id = classId()
		slide id
		@subscribe 'classInfo', id
		@subscribe 'externalGrades', classId: id

	@autorun ->
		c = currentClass()
		return unless c?

		setPageOptions
			title: c.name
			color: c.__color

		if c.__classInfo.bookId?
			noticeBanner.set undefined
		else
			noticeBanner.set
				content: 'Voeg een methode toe om betere zoekresultaten te krijgen.'
				onClick: ->
					ga 'send', 'event', 'banner', 'click', 'no books banner'
					showModal 'changeClassModal', undefined, currentClass

Template.classView.events
	"click #changeClassIcon": ->
		ga 'send', 'event', 'changeClassModal', 'open'
		showModal 'changeClassModal', undefined, currentClass

	'click #banner': -> @onClick?()

	'keydown #searchBar > input': (event) ->
		query = event.target.value.trim()

		if event.which is 13 and query.length > 0
			searchRes.set undefined
			Meteor.call 'search', query, {
				classIds: [ classId() ]
				defaultKeywords: [ 'vocab', 'report' ]
				onlyFrom: [ 'woordjesleren', 'scholieren', 'studyUtil files' ] # REVIEW: is this needed?
				maxItems: 30
			}, (e, r) ->
				if e? then notify 'Fout tijdens zoeken', 'error'
				else searchRes.set r

			$('#searchBar > input').blur()
			showModal 'searchResultsModal', undefined, { query }
		else if event.which is 27
			event.target.value = ''
			event.target.blur()

	'click #gradesButton': -> FlowRouter.go 'grades', {}, classIds: [ classId() ]
	'click #hoursButton': ->
		ga 'send', 'event', 'click', 'nextHourButton'
		nextHourDate = CalendarItems.findOne({
			userIds: Meteor.userId()
			classId: classId()
			startDate: $gte: new Date
			scrapped: false
		}, {
			sort:
				startDate: 1
		})?.startDate

		if nextHourDate?
			FlowRouter.go 'calendar', time: nextHourDate.getTime()

	'click #nextTestButton': ->
		ga 'send', 'event', 'click', 'nextTestButton'
		test = getNextTest()
		if test?
			FlowRouter.go(
				'calendar'
				{ time: +test.startDate }
				{ openCalendarItemId: test._id }
			)

	'click #projectsButton': ->
		ga 'send', 'event', 'projectsModal', 'open'
		showModal 'projectsModal'

	'click #teacherButton': ->
		ga 'send', 'event', 'click', 'teacherButton'
		FlowRouter.go 'composeMessage', undefined,
			recipients: @__classInfo.externalInfo.teacherName

	'click #chatContainer > header': ->
		ga 'send', 'event', 'click', 'chatContainerHeader'
		ChatManager.openClassChat @_id

Template.classView.onRendered ->
	$searchInput = @$ '#searchBar > input'

	@autorun ->
		classId()
		$searchInput.val ''

	Mousetrap.bind 's', ->
		$searchInput.focus()
		no

Template.classView.onDestroyed ->
	Mousetrap.unbind 's'

Template.chatPersonRow.events
	'click': ->
		ga 'send', 'event', 'click', 'chatPersonRow'
		FlowRouter.go 'personView', id: @_id

Template.changeClassModal.events
	'click #goButton': ->
		bookName = $('#changeBookInput').val()

		c = currentClass()
		Meteor.call 'insertBook', bookName, c._id, (e, r) ->
			if e? then notify 'Fout tijdens methode veranderen', 'error'
			else
				Meteor.call 'setClassBookId', c._id, r, ->
					noticeBanner.set undefined
					notify 'Methode veranderd', 'notice'
					ga 'send', 'event', 'changeClassModal', 'save'
					$('#changeClassModal').modal 'hide'

	'click #hideClassButton': ->
		userId = Meteor.userId()
		ga 'send', 'event', 'class', 'hide'

		setHidden = (val) =>
			Meteor.call 'setClassHidden', @_id, val

		show = =>
			setHidden no
			notify "#{@name} zichtbaar gemaakt", 'success'

		hide = =>
			FlowRouter.go 'overview'
			setHidden yes
			handle = NotificationsManager.notify
				body: "<b>#{@name} verborgen</b>"
				html: yes

				buttons: [{
					label: 'ongedaan maken'
					callback: show
				}]

		$('#changeClassModal').modal 'hide'
		if getEvent('classHideHint')?
			hide()
		else # show one-time hint modal.
			alertModal(
				'Zeker weten?'
				'''
					Als je dit vak verbergt kan je het niet meer zien in de zijbalk, je kan
					het vak weer toonbaar maken in instellingen > vakken.
				''',
				DialogButtons.OkCancel
				{ main: 'Verbergen', second: 'Toch niet' }
				{ main: 'btn-danger' }
				main: ->
					hide()
					Meteor.call 'markUserEvent', 'classHideHint'
			)

Template.changeClassModal.onRendered ->
	@autorun -> BooksHandler.run currentClass()

	@$('#changeBookInput').typeahead(null,
		source: BooksHandler.engine.ttAdapter()
		displayKey: 'title'
	).on 'typeahead:selected', (obj, datum) -> Session.set 'currentSelectedBookDatum', datum

Template.searchResultsModal.helpers
	isLoading: -> not searchRes.get()?
	results: -> searchRes.get()

Template.searchResultsModal.onRendered ->
	Mousetrap.bind 'esc', ->
		$('#searchResultsModal').modal 'hide'
		no

Template.searchResultsModal.onDestroyed ->
	Mousetrap.unbind 'esc'

Template['searchResultsModal_result'].helpers
	__insufficient: -> if @rating < 5.5 then 'insufficient' else ''

Template.projectsModal.helpers
	projects: ->
		Projects.find {
			classId: classId()
			participants: Meteor.userId()
		}, {
			sort:
				finished: 1
				deadline: 1
				name: 1
		}

Template.projectsModal.events
	'click #addProjectButton': -> showModal 'addProjectModal'
Template.projectRow.events
	'click': -> FlowRouter.go 'projectView', id: @_id

externalAssignments = new ReactiveVar
Template.addProjectModal.helpers
	assignments: ->
		externalAssignments.get()?.map (a) ->
			_class = -> Classes.findOne a.classId
			_.extend a,
				__project: -> Projects.findOne externalId: a.externalId
				__class: _class
				__abbreviation: -> _class().abbreviations[0]

	classes: -> classes()
	selected: (event, _class) -> Session.set 'currentSelectedClassDatum', _class

Template.addProjectModal.events
	'click #createButton': ->
		return # TODO
		project = new Project(
			@name
			@description
			@deadline
			Meteor.userId()
			@classId
			{
				id: @externalId
				fetchedBy: @fetchedBy
				name: @name
			}
		)
		Projects.insert project
		$('#addProjectModal').modal 'hide'

	'click #goButton': ->
		name = $('#addProjectModal #nameInput').val().trim()
		description = $('#addProjectModal #descriptionInput').val().trim()
		deadline = $('#addProjectModal #deadlineInput').data('DateTimePicker').date().toDate()

		if name.length is 0
			setFieldError '#nameGroup', 'Naam kan niet leeg zijn.'
			return

		Meteor.call 'insertProject', name, description, deadline, classId(), (e, r) ->
			if e?
				if e.error is 'project-exists'
					setFieldError '#nameGroup', 'Je hebt al een project met dezelfde naam'
				else
					notify 'Onbekende fout opgetreden tijdens project aanmaken', 'error'
					shake '#addProjectModal'

			else
				notify 'Project aangemakt', 'notice'
				$('#addProjectModal').modal 'hide'

Template.addProjectModal.onRendered ->
	$('#deadlineInput').datetimepicker defaultDate: new Date()

	### TODO
	Meteor.call 'getExternalAssignments', (e, r) ->
		externalAssignments.set r unless e?
	###

Template.infoContainer.onCreated ->
	@autorun =>
		@subscribe 'externalStudyUtils', classId: classId()

Template.infoContainer.helpers
	items: ->
		StudyUtils.find {
			userIds: Meteor.userId()
			classId: classId()
		}, {
			sort:
				updatedOn: -1
				name: 1
		}

Template.studyUtil.helpers
	description: -> Helpers.convertLinksToAnchor _.escape @description
	files: ->
		Files.find {
			_id: $in: @fileIds ? []
		}, {
			sort:
				creationDate: -1
				name: 1
		}

Template.studyUtil.onCreated ->
	@subscribe 'files', @data?.fileIds ? []
