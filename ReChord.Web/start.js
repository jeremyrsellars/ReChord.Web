require('coffee-script');
var app = new (require('./webapp.coffee').WebApp)();
app.configureWeb();
require('http').createServer(app.app).listen(80);
