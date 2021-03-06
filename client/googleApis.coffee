# TODO: refactor this code to use drive api v3

pickerLoaded = new ReactiveVar no
authLoaded = new ReactiveVar no
@driveLoaded = new ReactiveVar no
pickerResult = new ReactiveVar null

authorized = no
oauthToken = null
@projectFilePicker = null

@onGoogleLoad = ->
	gapi.client.setApiKey 'AIzaSyDZldjOJq0jrsi5IhtBIGz1ZHhbF3g-_ec'

	gapi.load 'auth', callback: -> authLoaded.set yes
	gapi.load 'picker', callback: -> pickerLoaded.set yes
	gapi.client.load('drive', 'v2').then -> driveLoaded.set yes

###*
# Start Google auth flow and assign a callback to the picker result.
#
# @method onPickerResult
# @param callback {Function} The callback to give the result of the picker to.
# @return {Tracker.Computation} A computation which can be stopped.
###
@onPickerResult = (callback) ->
	projectFilePicker?.setVisible? yes

	Tracker.autorun (c) ->
		if authLoaded.get() and not authorized
			authorized = yes
			gapi.auth.authorize {
				'client_id': '319072777142-apafv4ffhg4sv4thrertjtjk2q8eelke.apps.googleusercontent.com'
				'scope': 'https://www.googleapis.com/auth/drive'
				'immediate': no
			}, (res) ->
				if res? and !res.error?
					oauthToken = res.access_token
					buildPicker()

		return unless pickerLoaded.get() and authLoaded.get() and driveLoaded.get() and pickerResult.get()?
		callback pickerResult.get()
		c.stop()
		pickerResult.set null

buildPicker = =>
	return unless pickerLoaded.get() and oauthToken? and !projectFilePicker?

	@projectFilePicker = new google.picker.PickerBuilder()
		.addView ( ->
			x = new google.picker.DocsView()
			x.setIncludeFolders yes
			x.setMode google.picker.DocsViewMode.LIST
			x.setOwnedByMe yes
			return x
		)()
		.addView new google.picker.DocsUploadView()
		.setOAuthToken oauthToken
		.setDeveloperKey 'AIzaSyDZldjOJq0jrsi5IhtBIGz1ZHhbF3g-_ec'
		.setCallback (data) -> pickerResult.set data if data.action isnt 'loaded'
		.setLocale 'nl'
		.build()
	@projectFilePicker.setVisible yes
