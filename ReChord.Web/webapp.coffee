fs = require 'fs'
path = require 'path'
express = require 'express'
connect = require 'connect'
rechord = require 'rechord'

console.combine = (a, item, remaining...) ->
   a.push item if item?
   console.combine a, remaining if remaining? and remaining.length > 0
console.logInColor = (octalColor, message) ->
   if require('util').isArray(message)
      console.logArrayInColor octalColor, message
      return
   console.logStringInColor octalColor, message
console.logArrayInColor = (octalColor, message) ->
   a = ['\u001b[' + octalColor]
   console.combine a, message
   a.push '\u001b[0m'
   console.log a.join('')
console.logStringInColor = (octalColor, message) ->
   console.log '\u001b[' + octalColor, message, '\u001b[0m'
console.red = (message) ->
   console.logInColor '31m', message
console.green = (message) ->
   console.logInColor '32m', message
console.gold = (message) ->
   console.logInColor '33m', message


class exports.WebApp
   constructor: (@port)->
      @port ?= process.env.PORT ? 2999

   run: ->
      process.title = 'ReChord Web App - initializing ' + @port
      @writeHeader()
      process.title += '.'
      @configureWeb()
      process.title += '.'
      @listen()
      process.title = 'ReChord Web App ' + @port

   writeHeader: ->
      console.log  '==================='
      console.gold ' ReChord Web App :' + @port
      console.log  '==================='

   configureWeb: =>
      console.log 'configuring web'
      @app = express()
      @app.use connect.favicon(__dirname + '/static/ReChord.ico')
      connect.logger.format 'prod_user', (tokens, req, res) =>
         ',{"date":"' + new Date().formatSortable().replace(' ', '_') +
         '","user":"' + (req.user ? "-").replace(/\\/g, '\\\\') +
         '","method":"' + req.method +
         '","url":"' + req.originalUrl +
         '","status":' + res.statusCode +
         ',"durationMs":' + (new Date - req._startTime) + '}'
      connect.logger.format 'dev_user', (tokens, req, res) =>
         status = res.statusCode
         statColor = 32
         userColor = 33
         userColor = 90 if @lastUser == req.user
         @lastUser = req.user

         if (status >= 500)
            statColor = 31
         else if (status >= 400)
            statColor = 33
         else if (status >= 300)
            statColor = 36

         '\u001b[' + userColor + 'm' + req.user + '\t\u001b[90m' + req.method + ' ' + req.originalUrl + ' ' +
            '\u001b[' + statColor + 'm' + res.statusCode + ' ' + @colorCodeMs(new Date - req._startTime)

      @app.configure 'debug', @configureDebug
      @app.configure 'production', @configureProduction

      @app.use express.bodyParser()

      @app.get '/logs/:log', (req, res) =>
         @respondWithLog req.params.log, res

      @app.use '/rechord',  require('connect').static(__dirname + '/static')
      @app.get '/rechord', (req,res) ->
         res.redirect '/rechord/Index.html'
      @app.get '/', (req,res) ->
         res.redirect '/rechord/Index.html'


      @app.post '/rechord/renderText',  (req,res) => 
         console.log '/rechord/renderText'

         offsets = (-parseInt(offset) for offset in req.body.capoPositions.split ' ')
         res.contentType "text/html"
         res.write "<html><head>
<style type='text/css'>
h1 {font-size: 14pt}
body {font-size: 12pt}
span.chord {font-family:lucida console, courier new, courier; color:blue; white-space: pre;}
span.lyric {font-family:lucida console, courier new, courier; white-space: pre;}
h1 {font-family:verdana, helvetica; font-size: 14pt}
</style>
</head>
<body>
"

         for offset in offsets
            res.write rechord.rechordHtml req.body.text, offset, rechord.preferSharps
            res.write '\r\n\r\n'

         res.end()
         #   (# rechord.main req.body.text, 0, prefer-sharps
         #   )
         console.log req.body.text

      process.openStdin().on 'keypress', (chunk,key)=>
         if key? and key.name == 'c' and key.ctrl
            console.red '             closing with ctrl+c'
            process.exit()
      process.stdin.setRawMode true
      
      process.on 'exit', =>
         @cleanup()

      console.log 'done'

   configureDebug: =>
      @logOptions = { immediate: false, format: 'dev_user' }
      @app.use connect.logger @logOptions

   configureProduction: =>
      @logPath = './logs/' + new Date().formatSortable() + '.json'
      @logOptions =
         immediate: false
         format: 'prod_user'
         buffer: 1000
         stream: @createLogFile @logPath
      @app.use connect.logger @logOptions
      console.gold 'configuring logger'

   respondWithLog: (name, res) =>
      console.red 'log requested: ' + name
      useCurrentLog = (/current/i).test name
      logPath = if useCurrentLog then @logPath else './logs/' + name + '.json'
      writeTerm = useCurrentLog
      # node verstions 0.6 and 0.8 supported: (fs.exists ? require('path').exists)
      (fs.exists ? require('path').exists) logPath, (exists) =>
         if exists
            @dumpLogToResponse logPath, res, writeTerm
         else
            res.statusCode = 404
            res.end 'not found: ' + name

   dumpLogToResponse: (logPath, res, writeTerm) ->
      rs = fs.createReadStream(logPath)
      rs.on 'end', ->
         res.end if writeTerm? then '\r\n]' else ''
      rs.pipe res, end:false

   colorCodeMs: (ms) ->
      if ms < 200
         '\u001b[90m' + ms + 'ms\u001b[0m'
      else if ms < 1000
         '\u001b[33m' + ms + 'ms\u001b[0m'
      else
         '\u001b[31m' + ms + 'ms\u001b[0m'

   createLogFile: (logPath)->
      s = fs.createWriteStream logPath, flags:'w'
      console.green 'opened writestream to log to ' + logPath
      s.write '[{}\r\n'
      s
   cleanup: =>
      @closeLog()

   closeLog: =>
      if @logOptions? and @logOptions.stream?
         s = @logOptions.stream
         s.end ']'

   listen: ->
      require('http').createServer(@app).listen @port
      console.green 'listening....'

   printRoutes: ->
      if @app.routes
         @app.routes.all().forEach (route) ->
            console.green route.method.toUpperCase() + ' ' + route.path
         console.log()
