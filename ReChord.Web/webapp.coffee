fs = require 'fs'
path = require 'path'
express = require 'express'
connect = require 'connect'

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
      process.title = 'ReChord Web App - initializing ' + @httpsPort
      @writeHeader()
      process.title += '.'
      @configureWeb()
      process.title += '.'
      @listen()
      process.title = 'ReChord Web App ' + @httpsPort

   writeHeader: ->
      console.log  '==================='
      console.gold ' ReChord Web App :' + @httpsPort
      console.log  '==================='

   configureWeb: =>
      console.log 'configuring web'
      @app = express()
      @app.use connect.favicon(__dirname + '/static/favicon.ico')
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

      @app.use '/static',  require('connect').static(__dirname + '/static')
      @app.get '/', (req,res) ->
         res.redirect '/static/Index.html'


      @app.post '/renderText',  (req,res) => 
         util   = require('util')
         spawn = require('child_process').spawn
         image = __dirname + """\\..\\rechord\\bin\\debug\\ReChord.exe"""
         reChord = spawn image, ['0', '-3', '-5']
         res.contentType "text/html"
         console.gold res.write

         reChord.stdout.on 'data', (data) ->
           console.log 'stdout: ' + data
           res.write data

         reChord.stderr.on 'data', (data) ->
           console.log 'stderr: ' + data

         reChord.on 'exit',  (code) ->
           console.log 'child process exited with code ' + code
           res.end()

         reChord.stdin.write req.body.text
         reChord.stdin.end()

      process.openStdin().on 'keypress', (chunk,key)=>
         if key? and key.name == 'c' and key.ctrl
            console.red '             closing with ctrl+c'
            process.exit()
      process.stdin.setRawMode true
      
      process.on 'exit', =>
         @cleanup()

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
