OAuth2 = require("oauth").OAuth2
express = require "express"
https = require "https"
FormData = require "form-data"
uuid = require "uuid"
fs = require "fs"

unless process.argv.length > 2
  console.log "Usage: coffee share-file.coffee myfile.png"
  return
fileToShare = process.argv[2]

# Some configurations needed to talk with The Grid API
config =
  host: "api.thegrid.io"
  port: 443
  path: "/share"
  app_id: process.env.THEGRID_APP_ID or ""
  app_secret: process.env.THEGRID_APP_SECRET or ""
  scopes: ["share"]
  authorization_url: "https://passport.thegrid.io/login/authorize"
  token_url: "https://passport.thegrid.io/login/authorize/token"
  callback_url: "http://localhost:3000/authenticated"


# The Grid API supports OAuth2 authentication
oauth = new OAuth2(
  config.app_id
  config.app_secret
  ""
  config.authorization_url
  config.token_url
  null
)

shareFile = (filePath, accessToken, callback) ->
  formData = new FormData()
  # It's interesting to use a valid UUID to keep track of the shared item
  formData.append "url", "content://#{uuid.v4()}"
  formData.append "type", "image/jpeg"
  formData.append "content", fs.createReadStream(filePath)
  opts =
    host: config.host
    port: config.port
    path: config.path
    method: "POST"
    headers: formData.getHeaders()
  # Add your `accessToken` to headers
  opts.headers["Authorization"] = "Bearer #{accessToken}"

  req = https.request opts
  formData.pipe req

  req.on "response", (result) ->
    console.log "Finished sharing #{result.headers.location}"
    callback()

# Create an app that will redirect us to The Grid `config.authorization_url` and
# then back to our `config.callback_url`
app = express()

app.get "/", (req, res) ->
  oauthURL = oauth.getAuthorizeUrl
    redirect_uri: config.callback_url
    scope: config.scopes
    response_type: "code"

  body = "<a href=\"#{oauthURL}\">Share <b>#{fileToShare}</b> on The Grid</a>"
  res.send body

app.get "/authenticated", (req, res) ->
  oauth.getOAuthAccessToken(
    req.query.code
    {"redirect_uri": config.callback_url, "grant_type": "authorization_code"}
    (err, accessToken, refreshToken, results) ->
      if err?
        res.send "Error: #{err}"
      if results.error?
        res.send "Error: #{JSON.stringify(results)}"
      # Receive the token for this session at `accessToken`
      shareFile fileToShare, accessToken, () =>
        res.send "File <b>#{fileToShare}</b> shared on The Grid!"
  )

app.listen 3000
console.log "Share your file at http://localhost:3000"
