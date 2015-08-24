root = this

@_ = lodash # Shortcut for lo-dash. Replaces underscore.

###*
# Returns today as an Date object.
#
# @method today
# @return {Date} Date object of today.
###
Date.today = -> new Date().date()

###*
# Adds the given ammount of days to the current/new Date object.
#
# @method addDays
# @param days {Number} The amount of days to add.
# @param newDate {Boolean} Whether or not to create a new Object.
# @return {Date} A Date object with the given ammount of days added.
###
Date::addDays = (days, newDate = false) ->
	check days, Number
	newDate = false unless Match.test newDate, Boolean

	if newDate
		new Date @getTime() + (86400000 * days)
	else
		@setDate @getDate() + days
		this

Date::date = -> new Date @getUTCFullYear(), @getMonth(), @getDate()

Array::remove = (item) ->
	if _.isObject(item) and _.contains _.keys(item), "_id"
		_.remove this, (i) -> EJSON.equals item._id, i._id
	else
		_.remove this, (i) -> EJSON.equals item, i

	this
Array::pushMore = (items) -> [].push.apply this, items; return this

###
# Static class containing helper methods.
#
# @class Helpers
# @static
###
class @Helpers
	###*
	# Returns the amount of days between the 2 given dates.
	#
	# @method daysRange
	# @param firstDate {Date} First date as a Date object.
	# @param lastDate {Date} Last date as a Date object.
	# @param useTime {Boolean} If true the calculation will conisder the time of the given dates.
	# @param round {Boolean} Whether or not to round the result.
	# @return {Number} Amount of days between the two given dates. Can be negative.
	###
	@daysRange: (firstDate, lastDate, useTime = yes, round = yes) ->
		if useTime
			moment(lastDate).diff firstDate, "days", not round
		else
			# When not using time, the result is always rounded.
			moment(lastDate.date()).diff firstDate.date(), "days"

	###*
	# Returns the current day of the week.
	#
	# @method currentDay
	# @return {DayEnum} The current day of the week.
	###
	@currentDay: -> Helpers.weekDay new Date

	###*
	# Gets the weekday of the given `date`.
	# Where 0 = monday and 6 = sunday
	#
	# @method weekDay
	# @param date {Date} The Date object to get the weekday from.
	# @return {Number} The weekday of `date`.
	###
	@weekDay: (date) -> if (date.getDay() - 1) >= 0 then date.getDay() - 1 else DayEnum.sunday

	###*
	# Converts the given date to a ISO 8601 format as YYYYMMDD.
	#
	# @method dateToIso
	# @param date {Date} A date object to convert.
	# @return {String} A date as ISO 8601 format as YYYYMMDD.
	###
	@dateToIso: (date) -> date.getUTCFullYear() + Helpers.addZero(date.getUTCMonth() + 1) + Helpers.addZero(date.getUTCDate())

	###*
	# Converts the given string as ISO 8601 format as YYYYMMDD to a Date object.
	#
	# @method isoToDate
	# @param isoDate {String} A date as ISO 8601 format as YYYYMMDD to convert.
	# @return {Date} The given ISO date as a Date object.
	###
	@isoToDate: (isoDate) -> new Date isoDate[0...4], isoDate[4...6] - 1, isoDate[6...8]

	###*
	# Adds a zero in front of the original number if it doesn't yet.
	#
	# @method addZero
	# @param original {Number|String} The number to add a zero in front to.
	# @return {String} The number as string with a zero in front of it.
	###
	@addZero: (original) -> if +original < 10 then "0#{original}" else original.toString()

	###*
	# Checks if the given original string contains the given query string.
	#
	# @method contains
	# @param original {String} The original string to search in.
	# @param query {String} The string to search for.
	# @param ignoreCasing {Boolean} Whether to ignore the casing of the search.
	# @return {Boolean} Whether the original string contains the query string.
	###
	@contains: (original, query, ignoreCasing = false) ->
		if ignoreCasing
			original
				.toUpperCase()
				.indexOf(query.toUpperCase()) >= 0
		else
			original
				.indexOf(query) >= 0

	###*
	# Returns all the matches of the given RegEx tested on the given string as strings.
	#
	# @method allMatches
	# @param regex {Regexp} The RegEx to use.
	# @param str {String} The string to test the RegEx on.
	# @return {String[]} An array containing all the matches found as strings. (example: ["hoofdstuk 4", "hoofdstuk 10"])
	###
	@allMatches: (regex, str) ->
		# If no global flag is set there's only one result.
		# Without this the while loop will be an infinite loop.
		return [regex.exec(str)?[0]] unless regex.global

		tmp = []
		tmp.push item[0] while (item = regex.exec str)?
		tmp

	###*
	# Returns all the matches of the given RegEx tested on the given string with the details.
	#
	# @method allMatchesDetailed
	# @param regex {Regexp} The RegEx to use.
	# @param str {String} The string to test the RegEx on.
	# @return {RegExpResult[]} An array containing all the matches found. As an addition it also contains `lastIndex: number`
	###
	@allMatchesDetailed: (regex, str) ->
		# If no global flag is set there's only one result.
		# Without this the while loop will be an infinite loop.
		return [regex.exec(str)] unless regex.global

		tmp = []

		while (item = regex.exec str)? then tmp.push _.extend item, lastIndex: item.index + item[0].length

		tmp

	###*
	# Returns the sum of the values in the given array.
	#
	# @method getTotal
	# @param arr {Array} The array to get the sum of.
	# @param [mapper] {Function} The function to map the values in the array to before counting it to the sum.
	# @return {Number} The sum of the given values.
	###
	@getTotal: (arr, mapper) ->
		sum = 0
		sum += (if _.isFunction(mapper) then mapper i else i) for i in arr
		sum

	###*
	# Returns the average of the values in the given array.
	#
	# @method getAverage
	# @param arr {Array} The array to get the average of.
	# @param [mapper] {Function} The function to map the values in the array to before counting it to the average.
	# @return {Number} The average of the given values.
	###
	@getAverage: (arr, mapper) -> @getTotal(arr, mapper) / arr.length

	###*
	# Caps the given string.
	# @method cap
	# @param string {String} The string to cap.
	# @param [amount=1] {Number} The amount of characters from index 0 of `string` to cap.
	# @return {String} The capped `string`.
	###
	@cap: (string, amount = 1) -> string[0...amount].toUpperCase() + string[amount..].toLowerCase()

	###*
	# Caps the given string, respecting name conventions.
	# @method nameCap
	# @param name {String} The name to cap.
	# @return {String} The capped `name`.
	###
	@nameCap: (name) ->
		words = name.toLowerCase().split /[\s-&]/g
		nonCapped = [
			"van"
			"vanden"
			"in"
			"uit"
			"der"
			"den"
			"de"
			"en"
			"of"
			"o"
		]

		name.toLowerCase().replace /\w+/g, (match) =>
			if match in nonCapped then match else @cap match

	###*
	# Find links in the given `string` and converts
	# those into anchor tags.
	#
	# @method convertLinksToAnchor
	# @param string {String} The string to convert.
	# @return {String} An HTML string containing the converted `string`.
	###
	@convertLinksToAnchor: (string) ->
		return undefined unless string?
		string.replace /[-a-zA-Z0-9@:%_\+.~#?&//=]{2,256}\.[a-z]{2,4}\b((\/|\?)[-a-zA-Z0-9@:%_\+.~#?&//=]+)?\b/ig, (match) ->
			if /^https?:\/\/.+/i.test match
				"<a target='_blank' href='#{match}'>#{match}</a>"
			else
				"<a target='_blank' href='http://#{match}'>#{match}</a>"

	@interval: (func, interval, bind = yes) ->
		if bind then func = _.bind func, stop: -> Meteor.clearInterval handle
		Meteor.defer func
		handle = Meteor.setInterval func, interval

	###*
	# Returns an array containg each day of the week starting on monday.
	# Respects the current moment locale.
	#
	# @method weekdays
	# @return {String[]}
	###
	@weekdays: ->
		_weekdays = moment()._locale._weekdays
		_(_weekdays)
			.slice 1
			.push _weekdays[0]
			.value()

	###
	# Returns the strength of the given `password`, Rules (and their weight)
	# stolen from http://www.passwordmeter.com/
	#
	# @method passwordStrength
	# @param password {String} The password to chec
	# @return {Number} The strength of `password`.
	###
	@passwordStrength: (password) ->
		uppercaseChars = _.filter password, (c) -> c.toUpperCase() is c
		lowercaseChars = _.filter password, (c) -> c.toLowerCase() is c
		numbers = _.reject password, (c) -> isNaN c
		symbols = _.filter password, (c) -> /[-!$%^&*()_+|~=`{}\[\]:";'<>?,.\/]/.test c
		middleNumbersOrSymbols =
			_.filter numbers.concat(symbols), (c, i) -> 0 < i < password.length-1
		len = password.length

		sum = 0
		sum += len * 4
		sum += numbers.length * 4
		sum += symbols.length * 6
		sum += middleNumbersOrSymbols.length * 2
		sum += (len - uppercaseChars.length) * 2
		sum += (len - lowercaseChars.length) * 2
		sum

	###*
	# Checks if the given `mail` is a valid address.
  #
	# @method correctMail
	# @param mail {String} The address to check.
	# @return {Boolean} True if the given mail is valid, otherwise false.
	###
	@correctMail: (mail) -> /(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])/i.test mail

	###*
	# Tests if the months and dates of the given two date objects are the same.
  #
	# @method datesEqual
	# @param a {Date}
	# @param b {Date}
	# @return {Boolean}
	###
	@datesEqual: (a, b) -> a.getMonth() is b.getMonth() and a.getDate() is b.getDate()

	###*
	# Emboxes the given `fn`, making the current computation only invalidate when
	# the return value of the given `fn` changes, also makes the `fn` stop
	# executing if it isn't used in any reactive computation.
	#
	# @method emboxValue
	# @param fn {Function}
	# @param [equals] {Function} An comperison value used instead of `EJSON.equals`.
	# @return {any} The return value of `fn`.
	###
	@emboxValue: (fn, equals) -> emboxValue(fn, { equals, lazy: yes })()

###*
# Checks if the given `user` is in the given `role`.
# @method userIsInRole
# @param [user=Meteor.user()] {User|String} The user or its ID to check.
# @param [role="admin"] {String} The role to check.
# @return {Boolean} True if the given `user` is in the given `role`.
###
@userIsInRole = (user = Meteor.user(), role = "admin") ->
	if _.isString(user) then user = Meteor.users.findOne user
	return no unless user?
	_.every (if _.isArray(role) then role else [role]), (s) -> _.contains user.roles, s

###*
# Generates a getter/setter method for a global class variable.
#
# @param varName {String} The name of the variable to make method for.
# @param pattern {Pattern} The Match pattern to test when the variable is being changed.
# @param allowChanges {Boolean} Whether to allow changes to the property (otherwise it's just going to generate a getter method)
# @param transformIn {Function} Function to map the new variable to before saving it.
# @param transformOut {Function} Function to map the variable that gets returned to.
# @return {Function} A getter/setter method for the given global class variable.
###
@getset = (varName, pattern = Match.Any, allowChanges = yes, transformIn, transformOut) ->
	(newVar) ->
		if newVar?
			if allowChanges
				@[varName] = if _.isFunction(transformIn) then transformIn newVar else newVar
			else
				throw new Error "Changes on this property aren't allowed"

		if _.isFunction(transformOut) then transformOut @[varName] else @[varName]
