Package.describe({
	name: 'simply:performance-logging',
	version: '0.0.1',
	summary: 'Simple loading performance stats',
	git: '',
	documentation: 'README.md',
});

Package.onUse(function(api) {
	api.versionsFrom('1.2.1');
	api.use('ecmascript');
	api.use([
		'mongo',
		'check',
	], 'server');
	api.mainModule('client.js', 'client');
	api.mainModule('server.js', 'server');
});
