Package.describe({
	name: 'scholieren',
	version: '0.0.1',
	// Brief, one-line summary of the package.
	summary: '',
	// URL to the Git repository containing the source code for this package.
	git: '',
	// By default, Meteor will default to using README.md for documentation.
	// To avoid submitting documentation, set this field to null.
	documentation: 'README.md',
});

Package.onUse(function(api) {
	api.versionsFrom('1.1.0.3');

	api.use([
		'http',
		'ecmascript',
		'stevezhu:lodash@3.10.1',
	], 'server');
	api.use('search', 'server', { weak: true });

	api.addFiles('scholieren.js', 'server');

	api.export('Scholieren', 'server');
});

Package.onTest(function(api) {
	api.use('tinytest');
	api.use('scholieren');
	api.addFiles('scholieren-tests.js');
});
