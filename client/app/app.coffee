@snapper = null
magisterClasses = new ReactiveVar null
class @App
	@_setupPathItems:
		tutorial:
			done: no
			func: (current, length) ->
				alertModal "Hey!", Locals["nl-NL"].GreetingMessage(), DialogButtons.Ok, { main: "verder" }, { main: "btn-primary" }, {main: ->
					App.step()
				}, no
		magisterInfo:
			done: no
			func: (current, length) ->
				$("#setMagisterInfoModal").modal backdrop: "static"
		plannerPrefs:
			done: no
			func: (current, length) ->
				$("#plannerPrefsModal").modal backdrop: "static"
				$("#plannerPrefsModal .modal-header button").remove()
		getMagisterClasses:
			done: no
			func: (current, length) ->
				$("#getMagisterClassesModal").modal backdrop: "static"

		newSchoolYear:
			done: no
			func: (current, length) ->
				alertModal "Hey!", Locals["nl-NL"].NewSchoolYear(), DialogButtons.Ok, { main: "verder" }, { main: "btn-primary" }, { main: -> return }, no
		final:
			done: no
			func: (current, length) ->
				swalert
					type: "success"
					title: "Klaar!"
					text: "Wil je een complete rondleiding volgen?"
					confirmButtonText: "Rondleiding"
					cancelButtonText: "Afsluiten"
					onSuccess: (->)
					onCancel: (->)
	
	@_fullCount: null
	@_currentCount: 0
	@_running: no

	###*
	# Moves the setup path one item further.
	#
	# @method step
	# @return {Object} Object that gives information about the progress of the setup path.
	###
	@step = ->
		return unless App._fullCount?
		App._currentCount++

		itemName = _.find _.keys(App._setupPathItems), (k) -> not App._setupPathItems[k].done
		
		item = App._setupPathItems[itemName]
		item.func App._currentCount, App._fullCount
		item.done = yes

		if App._currentCount + 1 is App._fullCount
			App._currentCount = 0
			App._fullCount = null
			@_running = no

		return { currentPosition: App._currentCount, length: App._fullCount, current: itemName }

	###*
	# Initializes and starts the setup path.
	#
	# @method followSetupPath
	###
	@followSetupPath: ->
		return if App._running
		App._setupPathItems.tutorial.done = Meteor.user().completedTutorial
		App._setupPathItems.plannerPrefs.done = App._setupPathItems.magisterInfo.done = Meteor.user().magisterCredentials?

		App._setupPathItems.newSchoolYear.done = Meteor.user().classInfo?

		App._fullCount = _.filter(App._setupPathItems, (x) -> not x.done).length
		App._setupPathItems.final.done = App._fullCount is 0
		App._running = yes
		App.step()

# == Bloodhounds ==

@bookEngine = new Bloodhound
	name: "books"
	datumTokenizer: (d) -> Bloodhound.tokenizers.whitespace d.name
	queryTokenizer: Bloodhound.tokenizers.whitespace
	local: []

classEngine = new Bloodhound
	name: "classes"
	datumTokenizer: (d) -> Bloodhound.tokenizers.whitespace d.val
	queryTokenizer: Bloodhound.tokenizers.whitespace
	local: []

# == End Bloodhounds ==

# == Modals ==

Template.getMagisterClassesModal.helpers
	magisterClasses: -> magisterClasses.get()

Template.getMagisterClassesModal.rendered = ->
	onMagisterInfoResult("classes", (e, r) -> magisterClasses.set r unless e?)
	onMagisterInfoResult "course", (e, r) ->
		return if e?

		schoolVariant = /[^\d\s]+/.exec(r.type().description)[0].trim()
		year = (Number) /\d+/.exec(r.type().description)[0].trim()

		Meteor.users.update Meteor.userId(), $set:
			"profile.courseInfo": {
				profile: r.profile()
				alternativeProfile: r.alternativeProfile()
				schoolVariant
				year
			}

	opts =
		lines: 17
		length: 7
		width: 2
		radius: 18
		corners: 0
		rotate: 0
		direction: 1
		color: "#000"
		speed: .9
		trail: 10
		shadow: no
		hwaccel: yes
		className: "spinner"
		top: "65%"
		left: "50%"

	spinner = new Spinner(opts).spin $("#spinner").get()[0]

Template.getMagisterClassesModal.events {}

Template.setMagisterInfoModal.events
	"click #goButton": ->
		schoolName = Helpers.cap $("#schoolNameInput").val()
		school = Session.get("currentSelectedSchoolDatum")
		school ?= { url: "" }
		username = $("#magisterUsernameInput").val()
		password = $("#magisterPasswordInput").val()

		school = Schools.findOne { name: schoolName }
		school ?= New.school schoolName, school.url, new Location()

		Meteor.call "setMagisterInfo", { school, schoolId: school._id, magisterCredentials: { username, password }}, (success) ->
			if success
				$("#setMagisterInfoModal").modal "hide"
				App.step()
				loadMagisterInfo yes
			else
				$("#setMagisterInfoModal").addClass "animated shake"
				$('#setMagisterInfoModal').one 'webkitAnimationEnd mozAnimationEnd MSAnimationEnd oanimationend animationend', ->
					$("#setMagisterInfoModal").removeClass "animated shake"

Template.setMagisterInfoModal.rendered = ->
	$("#schoolNameInput").typeahead({
		minLength: 3
	}, {
		displayKey: "name"
		source: (query, callback) ->
			MagisterSchool.getSchools query, (e, r) -> callback r unless e?
	}).on "typeahead:selected", (obj, datum) -> Session.set "currentSelectedSchoolDatum", datum

dayWeek = [{ friendlyName: "Maandag", name: "monday" }
	{ friendlyName: "Dinsdag", name: "tuesday" }
	{ friendlyName: "Woensdag", name: "wednesday" }
	{ friendlyName: "Donderdag", name: "thursday" }
	{ friendlyName: "Vrijdag", name: "friday" }
	{ friendlyName: "Zaterdag", name: "saturday" }
	{ friendlyName: "Zondag", name: "sunday" }
]

Template.plannerPrefsModal.helpers
	dayWeek: -> dayWeek
	weigthOptions: -> return [ { name: "Geen" }
		{ name: "Weinig" }
		{ name: "Gemiddeld", selected: true }
		{ name: "Veel" }
	]

Template.plannerPrefsModal.rendered = ->
	# Set the data on the modal, if available
	return unless Get.schedular()?

	dayWeeks = _.sortBy _.filter(Get.schedular().schedularPrefs().dates(), (dI) -> !dI.date()? and _.isNumber dI.weekday()), (dI) -> dI.weekday()
	return if dayWeeks.length isnt 7

	for i in [0...dayWeek.length]
		day = dayWeeks[i]
		value = switch day.availableTime()
			when 0 then "Geen"
			when 1 then "Weinig"
			when 2 then "Gemiddeld"
			when 3 then "Veel"
		$("##{dayWeek[i].name}Input").val value

Template.plannerPrefsModal.events
	"click #goButton": =>
		schedular = Get.schedular() ? New.schedular Meteor.userId()
		schedularPrefs = new SchedularPrefs
		for day in dayWeek
			schedularPrefs.dates().push @DayEnum[Helpers.cap day.name], switch $("##{day.name}Input").val()
				when "Geen" then 0
				when "Weinig" then 1
				when "Gemiddeld" then 2
				when "Veel" then 3
		schedular.schedularPrefs schedularPrefs
		Meteor.users.update Meteor.userId(), $set: { schedular }

		$("#plannerPrefsModal").modal "hide"

		App.step()

Template.addClassModal.events
	"click #goButton": (event) ->
		name = Helpers.cap $("#classNameInput").val()
		course = $("#courseInput").val().toLowerCase()
		bookName = $("#bookInput").val()
		color = $("#colorInput").val()
		{ year, schoolVariant } = Meteor.user().profile.courseInfo

		_class = Classes.findOne { $or: [{ _name: name }, { _course: course }], _schoolVariant: schoolVariant, _year: year}
		_class ?= New.class name, course, year, schoolVariant

		book = _class.books().smartFind bookName, (b) -> b.title()
		unless book?
			book = new Book _class, bookName, undefined, Session.get("currentSelectedBookDatum")?.id, undefined
			Classes.update _class._id, $push: { _books: book }

		Meteor.users.update Meteor.userId(), $push: { classInfos: { id: _class._id, color, bookId: book._id }}
		$("#addClassModal").modal "hide"

	"keypress #classNameInput": (event) ->
		return if event.which is 0
		val = Helpers.cap $("#classNameInput").val()

		if /(Natuurkunde)|(Scheikunde)/ig.test val
			val = "Natuur- en scheikunde"
		else if /(Wiskunde( (a|b|c|d))?)|(Rekenen)/ig.test val
			val = "Wiskunde / Rekenen"
		else if /levensbeschouwing/ig.test val
			val = "Godsdienst en levensbeschouwing"

		WoordjesLeren.getAllBooks val, (result) ->
			bookEngine.clear()
			bookEngine.add result

Template.addClassModal.rendered = ->
	$("#colorInput").colorpicker color: "#333"
	$("#colorInput").on "changeColor", -> $("#colorLabel").css color: $("#colorInput").val()

	WoordjesLeren.getAllClasses (result) ->
		#classes = Classes.find(_name: $nin: (Helpers.cap c for c in result.pushMore(extraClassList) )).map((c) -> c._name).pushMore(extraClassList).pushMore(result)
		try
			classEngine.add ( { val: s } for s in result.pushMore(extraClassList) when !_.contains ["Overige talen",
				"Overige vakken",
				"Eigen methodes",
				"Wiskunde / Rekenen",
				"Natuur- en scheikunde",
				"Godsdienst en levensbeschouwing"], s )

	bookEngine.initialize()
	classEngine.initialize()

	$("#bookInput").typeahead(null,
		source: bookEngine.ttAdapter()
		displayKey: "name"
	).on "typeahead:selected", (obj, datum) -> Session.set "currentSelectedBookDatum", datum

	$("#classNameInput").typeahead null,
		source: classEngine.ttAdapter()
		displayKey: "val"

Template.settingsModal.events
	"click #schedularPrefsButton": ->
		$("#settingsModal").modal "hide"
		$("#plannerPrefsModal").modal()
	"click #accountInfoButton": ->
		$("#settingsModal").modal "hide"
		$("#accountInfoModal").modal()
	"click #logOutButton": ->
		Router.go "app"
		Meteor.logout()

Template.newSchoolYearModal.helpers classes: -> classes()

Template.newSchoolYearModal.events
	"change": (event) ->
		target = $(event.target)
		checked = target.is ":checked"
		classId = target.attr "classid"

		target.find("span").css color: if checked then "lightred" else "white"

Template.accountInfoModal.helpers currentMail: -> Meteor.user().emails[0].address

Template.accountInfoModal.events
	"click #goButton": ->
		mail = $("#mailInput").val().toLowerCase()
		oldPass = $("#oldPassInput").val()
		newPass = $("#newPassInput").val()
		newMail = mail isnt Meteor.user().emails[0].address
		hasNewPass = oldPass isnt "" and newPass isnt ""

		if newMail
			Meteor.call "changeMail", mail
			$("#accountInfoModal").modal "hide"
			unless hasNewPass then swalert title: "Mailadres aangepast", type: "success", text: "Je krijgt een mailtje op je nieuwe email adress voor verificatie"

		if hasNewPass and oldPass isnt newPass
			Accounts.changePassword oldPass, newPass, (error) ->
				if error?.reason is "Incorrect password"
					$("#oldPassInput").addClass("has-error").tooltip(placement: "bottom", title: "Verkeerd wachtwoord").tooltip("show")
				else
					$("#accountInfoModal").modal "hide"
					swalert title: ":D", type: "success", text: "Wachtwoord aangepast! Voortaan kan je met je nieuwe wachtwoord inloggen." + (if newMail then "Je krijgt een mailtje op je nieuwe email adress voor verificatie" else "")
		else if oldPass is newPass
			$("#newPassInput").addClass("has-error").tooltip(placement: "bottom", title: "Nieuw wachtwoord is hetzelfde als je oude wachtwoord.").tooltip("show")


# == End Modals ==

# == Sidebar ==

Template.sidebar.helpers
	"classes": -> classes()
	"sidebarOverflow": -> if Session.get "sidebarOpen" then "auto" else "hidden"

Template.sidebar.events
	"click .bigSidebarButton": (event) ->
		#targetPosition = (Number) event.currentTarget.attributes["pos"].value
		#classId = classes()[targetPosition - 1]._id unless targetPosition is 0
		
		#Session.set "selectedClassPosition", targetPosition
		#Session.set "selectedClassId", classId

		#if targetPosition is 0 then Router.go "app" else Router.go "classView", classId: classId.toHexString()
		slide $(event.target).attr "id"

	"click .sidebarFooterSettingsIcon": -> $("#settingsModal").modal()
	"click #addClassButton": ->
		# Reset AddClassModal inputs
		$("#classNameInput").val("")
		$("#courseInput").val("")
		$("#bookInput").val("")
		$("#colorInput").colorpicker 'setValue', "#333"

		$("#addClassModal").modal()

# == End Sidebar ==

Template.app.helpers
	contentOffsetLeft: -> if Session.get "isPhone" then "0" else "200px"

Template.app.rendered = ->
	Deps.autorun -> if Meteor.user()? then Meteor.subscribe "essentials", -> loadMagisterInfo()
	
	notify("Je hebt je account nog niet geverifiëerd!", "warning") unless Meteor.user().emails[0].verified
	onMagisterInfoResult "assignments soon", (e, r) ->
		return if e? or r.length is 0
		s = "Deadlines van opdrachten binnenkort:\nKlik voor meer info.\n\n"
		for assignment in _.uniq(r, "_class") then do (assignment) ->
			d = if (d = assignment.deadline()).getHours() is 0 and d.getMinutes() is 0 then d.addDays(-1) else d
			s += "<b>#{assignment.class().abbreviation()}</b> - #{DayToDutch(Helpers.weekDay(d))}\n"

		NotificationsManager.notify body: s, type: "warning", time: -1, html: yes, onClick: (event) -> console.log ":D"

	onMagisterInfoResult "grades", (e, r) ->
		return if e? or r.length is 0

		endGrades = _.filter r, (g) -> g.type().header().toLowerCase() is "eind"
		if endGrades.length is 0
			endGrades = _.filter r, (g) -> g.type().header().toLowerCase() is "e-jr"

		recentGrades = _.filter r, (g) -> new Date(g.dateFilledIn()) > Date.today().addDays(-7) and _.contains ["pw", "ow"], g.type().header().toLowerCase()
		unless recentGrades.length is 0
			s = "Recent ontvangen cijfers:\n\n"

			for c in (z.class() for z in _.uniq recentGrades, (g) -> g.class().id())
				grades = _.filter recentGrades, (g) -> g.class() is c
				s += "<b>#{c.abbreviation()}</b> - #{grades.map((z) -> if Number(z.grade().replace(",", ".")) < 5.5 then "<b style=\"color: red\">#{z.grade()}</b>" else z.grade()).join ', '}\n"

			NotificationsManager.notify body: s, type: "warning", time: -1, html: yes, onClick: (event) -> console.log ":D"

	ChatHeads.initialize()

	Deps.autorun ->
		if Meteor.user()? and !Meteor.user().hasPremium
			setTimeout (-> Meteor.defer ->
				if !Session.get "adsAllowed"
					Router.go "launchPage"
					Meteor.logout()
					swalert title: "Adblock :c", html: 'Om simplyHomework gratis beschikbaar te kunnen houden zijn we afhankelijk van reclame-inkomsten.\nOm simplyHomework te kunnen gebruiken, moet je daarom je AdBlocker uitzetten.\nWil je toch simplyHomework zonder reclame gebruiken, dan kan je <a href="/">premium</a> nemen.', type: "error"
			), 3000

	setSwipe() if Session.get "isPhone"

	if !amplify.store("allowCookies") and $(".cookiesContainer").length is 0
		UI.insert UI.render(Template.cookies), $("body").get()[0]
		$(".cookiesContainer").css visibility: "initial"
		$(".cookiesContainer").velocity { bottom: 0 }, 1200, "easeOutExpo"
		$("#acceptCookiesButton").click ->
			amplify.store "allowCookies", yes
			$(".cookiesContainer").velocity { bottom: "-500px" }, 2400, "easeOutExpo", -> $(".cookiesContainer").remove()

setSwipe = ->
	snapper = new Snap
		element: $(".content")[0]
		maxPosition: 200
		flickThreshold: 45
		minPosition: 0
		resistance: .9

	snapper.on "end", -> Session.set "sidebarOpen", snapper.state().state is "left"
	snapper.on "animated", -> Session.set "sidebarOpen", snapper.state().state is "left"

	@closeSidebar = -> snapper.close()