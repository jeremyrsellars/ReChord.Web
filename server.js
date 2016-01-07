require('coffee-script');
var app = new (require('./webapp.coffee').WebApp)();
app.run();
// app.configureWeb();
// require('http').createServer(app.app).listen(process.env.PORT || 80);
