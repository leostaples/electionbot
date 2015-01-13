fs = require('fs')
https = require("https")

locatorOptions =
  host: "api.int.bbc.co.uk"
  cert: fs.readFileSync("/Users/leostaples/responsive-news/scripts/certs/certificate.pem")
  key: fs.readFileSync("/Users/leostaples/responsive-news/scripts/certs/certificate.pem")
  ca: fs.readFileSync("/Users/leostaples/responsive-news/scripts/certs/ca.pem")
  agent: false
  rejectUnauthorized: false
  headers: { 'Accept': 'application/json' }

module.exports = (robot) ->
  robot.respond /postcode (.*)/i, (msg) ->
    postcode = msg.match[1] #TODO: postcode validation
    path = "/locator/locations/#{postcode}/details/gss-council"

    getLocation msg, path, (response) ->
      msg.send response

getLocation = (msg, path, cb) ->
  locatorOptions.path = path

  req = https.request(locatorOptions, (res) ->
    dataString = ""
    res.on "data", (d) ->
      dataString += d.toString()
      return

    res.on "end", ->
      jsonResult = JSON.parse(dataString)

      if jsonResult.response.details[0]
        nearest = jsonResult.response.details[0]
        council = nearest.data.geographyName
        gssid = nearest.externalId

        getElectionResult msg, council, gssid, cb
      return

    return
  )
  req.end()
  req.on "error", (e) ->
    console.error e
    return

getElectionResult = (msg, council, gssid, cb) ->
  q = variant: gssid

  msg.http("http://components.election-data.cloud.bbc.co.uk/component/england_council_flash")
    .query(q)
    .get() (err, res, body) ->
      result = body.match(/<div[^>]*>\s*(\w+\s\w*)?\s*<\/div>/)
      cb council + ': ' + result[1]
