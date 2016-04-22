NoticeManager.provide 'serviceUpdates', ->
	unless getUserField Meteor.userId(), 'settings.devSettings.serviceUpdateNotices'
		return []

	@subscribe 'serviceUpdates'

	ServiceUpdates.find({}).map (u) ->
		service = _.find ExternalServicesConnector.services, name: u.fetchedBy
		id: u._id

		header: u.header
		subheader: "Mededeling via #{service.friendlyName}"

		template: 'serviceUpdateNotice'
		priority: u.priority - 10
		data: u