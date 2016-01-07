# TODO: cleanup

noticeBanner = new ReactiveVar
searchRes = new ReactiveVar undefined

selectedGradeId = new SReactiveVar Match.Optional Mongo.ObjectID
digitalSchoolUtilities = new ReactiveVar []

classId = -> FlowRouter.getParam 'id'
currentClass = -> Classes.findOne classId()
getChatRoom = ->
	id = classId()
	ChatRooms.findOne
		type: 'class'
		'classInfo.ids': id

getGrades = ->
	Grades.find
		ownerId: Meteor.userId()
		classId: classId()

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

	endGrade: ->
		Grades.findOne
			classId: @_id
			ownerId: Meteor.userId()
			isEnd: yes

	hoursPerWeek: ->
		CalendarItems.find(
			userIds: Meteor.userId()
			classId: classId()
			startDate: $gte: Date.today()
			endDate: $lte: Date.today().addDays 7
		).count()
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
		Meteor.users.find _id: $in: getChatRoom()?.users ? []

	###
	endGrade: ->
		cursor = Grades.find
			classId: @_id
			ownerId: Meteor.userId()
			isEnd: yes

		if cursor.count() is 1 then cursor.fetch()[0]
		else
			grades = Grades.find(
				classId: @_id
				ownerId: Meteor.userId()
				isEnd: no
			).fetch()

			sum = 0
			count = 0
			for grade in grades
				sum += grade.grade * grade.weight
				count += grade.weight

			g = sum / count
			res = new Grade g, 1, @_id, Meteor.userId()
			res.isEnd = yes
			_.extend res,
				# TODO: clean this up, this is an exact copy of the code in
				# collections.coffee.
				__insufficient: if g.passed then '' else 'insufficient'
				__grade: g.toString().replace '.', ','
	###

Template.classView.onCreated ->
	@autorun =>
		id = classId()
		slide id
		@subscribe 'classInfo', id
		@subscribe 'externalStudyUtils', id
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
					analytics?.track 'Click no book banner', className: c.name
					showModal 'changeClassModal', undefined, currentClass

	@autorun ->
		unless _.any(getGrades().fetch(), (g) -> EJSON.equals selectedGradeId.get(), g._id)
			selectedGradeId.set getGrades().fetch()[0]?._id

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

Template.classView.events
	"click #changeClassIcon": ->
		analytics?.track 'Open ChangeClassModal', className: @name
		showModal 'changeClassModal', undefined, currentClass

	'click #banner': -> @onClick?()

	'keydown #searchBar > input': (event) ->
		query = event.target.value.trim()

		if event.which is 13 and query.length > 0
			searchRes.set undefined
			Meteor.call 'search', query, {
				classIds: [ classId() ]
			}, (e, r) ->
				if e? then notify 'Fout tijdens zoeken', 'error'
				else searchRes.set r

			$('#searchBar > input').blur()
			showModal 'searchResultsModal', undefined, { query }
		else if event.which is 27
			event.target.value = ''
			event.target.blur()

	'click #gradesButton': ->
		showModal 'gradesModal'
	'click #hoursButton': ->
		nextHourDate = CalendarItems.findOne({
			userIds: Meteor.userId()
			classId: classId()
			startDate: $gte: new Date
		}, {
			sort:
				startDate: 1
		})?.startDate

		if nextHourDate?
			FlowRouter.go 'calendar', time: nextHourDate.getTime()

	'click #projectsButton': ->
		showModal 'projectsModal'

	'click #teacherButton': ->
		FlowRouter.go 'composeMessage', undefined,
			recipients: @__classInfo.externalInfo.teacherName

	'click #chatContainer > header': ->
		ChatManager.openClassChat @_id

Template.chatPersonRow.events
	'click': -> FlowRouter.go 'personView', id: @_id

Template.changeClassModal.onRendered ->
	@autorun -> BooksHandler.run currentClass()

	@$('#changeBookInput').typeahead(null,
		source: BooksHandler.engine.ttAdapter()
		displayKey: 'title'
	).on 'typeahead:selected', (obj, datum) -> Session.set 'currentSelectedBookDatum', datum

Template.changeClassModal.events
	'click #goButton': ->
		bookName = $('#changeBookInput').val()

		c = currentClass()
		Meteor.call 'insertBook', bookName, c._id, (e, r) ->
			if e? then notify 'Fout tijdens methode veranderen', 'error'
			else
				Meteor.users.update Meteor.userId(), $pull: classInfos: id: c._id
				Meteor.users.update Meteor.userId(), $push: classInfos:
					_.extend c.__classInfo, bookId: r

				noticeBanner.set undefined
				notify 'Methode veranderd', 'notice'
				analytics?.track 'Class Info Changed', className: @name
				$('#changeClassModal').modal 'hide'

	'click #hideClassButton': ->
		userId = Meteor.userId()

		deleteOld = =>
			Meteor.users.update userId, $pull: classInfos: id: @_id
		hide = =>
			FlowRouter.go 'overview'

			deleteOld()
			Meteor.users.update userId, $push: classInfos:
				_.extend @__classInfo, hidden: yes

			NotificationsManager.notify
				body: "<b>#{@name} verborgen</b>"
				html: yes

				labels: [ 'ongedaan maken' ]
				callbacks: [ show ]
		show = =>
			deleteOld()
			Meteor.users.update userId, $push: classInfos:
				_.extend @__classInfo, hidden: no
			notify "#{@name} zichtbaar gemaakt", 'success'

		$('#changeClassModal').modal 'hide'
		if getEvent('classHideHint')?
			hide()
		else
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

Template.gradeRow.events "click .gradeRow": -> selectedGradeId.set @_id

Template.gradeRow.helpers selected: -> if selectedGradeId.get() is @_id then "selected" else ""

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
	__insufficient: ->
		rating = parseFloat @rating
		if _.isNaN(rating) or rating > 5.5 then ''
		else 'insufficient'

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
	'click': -> FlowRouter.go 'projectView', id: @_id.toHexString()

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
			setFieldError '#projectNameGroup', 'Naam kan niet leeg zijn.'
			return

		Meteor.call 'insertProject', name, description, deadline, classId(), (e, r) ->
			if e?
				if e.error is 'project-exists'
					setFieldError '#projectNameGroup', 'Je hebt al een project met dezelfde naam'
				else
					notify 'Onbekende fout opgetreden tijdens project aanmaken', 'error'
					shake '#addProjectModal'

			else
				notify 'Project aangemakt', 'notice'
				$('#addProjectModal').modal 'hide'

Template.addProjectModal.onRendered ->
	$('#deadlineInput').datetimepicker
		locale: moment.locale()
		defaultDate: new Date()
		icons:
			time: 'fa fa-clock-o'
			date: 'fa fa-calendar'
			up: 'fa fa-arrow-up'
			down: 'fa fa-arrow-down'
			previous: 'fa fa-chevron-left'
			next: 'fa fa-chevron-right'

	### TODO
	Meteor.call 'getExternalAssignments', (e, r) ->
		externalAssignments.set r unless e?
	###

Template.gradesModal.helpers
	gradeGroups: ->
		arr = getGrades().fetch()
		_(arr)
			.reject (g) -> g.isEnd
			.uniq (g) -> g.period.id
			.map (g) ->
				name: g.period.name
				grades: (
					_(arr)
						.filter (x) -> x.period.id is g.period.id
						.value()
				)
			.filter (gp) -> gp.grades.length isnt 0
			.value()

	hasGrades: -> getGrades().count() > 0

	selectedGrade: ->
		Grades.findOne selectedGradeId.get()
