Package.describe({
	name: 'simply:notices',
	version: '0.0.1',
	summary: 'swagger notices everywhere.',
	git: '',
	documentation: 'README.md',
});

Package.onUse(function(api) {
	api.versionsFrom('1.2.1');
	api.use([
		'coffeescript',
		'check',
		'stevezhu:lodash@3.10.1',
		'mongo',
	]);
	api.use([
		'tracker',
		'reactive-var',
		'templating',
		'mquandalle:stylus',
		'handlebars',
		'schedule-functions',
		'meteorhacks:subs-manager',
	], 'client');
	/*
	api.use([
		'reywood:publish-composite',
	], 'server');
	*/

	api.addFiles([
		'lib/collections.coffee',
		'lib/schemas.coffee',
		'lib/methods.coffee',
	]);
	api.addFiles([
		'client/noticesManager.coffee',
		'client/notices.html',
		'client/notices.styl',
		'client/notices.coffee',

		'client/recentGrades/recentGrades.html',
		'client/recentGrades/recentGrades.styl',
		'client/recentGrades/recentGrades.coffee',

		'client/tasks/tasks.html',
		'client/tasks/tasks.styl',
		'client/tasks/tasks.coffee',

		'client/lessons/currentLesson.html',
		'client/lessons/currentLesson.coffee',
		'client/lessons/nextlesson.html',
		'client/lessons/nextlesson.coffee',
		'client/lessons/lessonsOverview.html',
		'client/lessons/lessonsOverview.styl',
		'client/lessons/lessonsOverview.coffee',

		'client/scrappedHours/srappedHours.html',
		'client/scrappedHours/srappedHours.styl',
		'client/scrappedHours/srappedHours.coffee',

		'client/tests/tests.html',
		'client/tests/tests.styl',
		'client/tests/tests.coffee',

		'client/birthday/birthday.html',
		'client/birthday/birthday.styl',
		'client/birthday/birthday.coffee',
	], 'client');
	api.addFiles([
		'server/security.coffee',
		'server/publish.coffee',
	], 'server');

	api.export([
		'NoticeManager',
		'Notifications',
	]);
});
