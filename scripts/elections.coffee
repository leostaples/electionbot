# Description:
#   Election results bot
#
# Todo:
#   council/general election query
#   find mp/twitter handle (csv)
#   local constituency news, hansard etc.
#   bot response if no elections/no result found
#   parliament api - full bio
#   use LDP lookup? (gssid->guid), get creativeworks about council
#   heroku/cert, locator api key?

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
  robot.respond /result (.*)/i, (msg) ->
    postcode = msg.match[1]

    if isValidPostcode postcode
      console.log "valid postcode"
      postcode = postcode.replace(' ','%20')
      path = "/locator/locations/#{postcode}/details/gss-council" #TODO: allow gss-seat queries

      getLocation msg, path, (response) ->
        msg.send response
    else
      console.log "invalid postcode"
      msg.send "Sorry but that is not valid postcode."

getLocation = (msg, path, cb) ->
  console.log "getting location for path #{path}"
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
  console.log "getting result for #{council} #{gssid}"

  #TODO: NI, Scotref endpoints based on gssid nation
  msg.http("http://components.election-data.cloud.bbc.co.uk/component/england_council_flash")
    .query(variant: gssid)
    .get() (err, res, body) ->
      result = body.match(/<div[^>]*>\s+(\w+[\s\w+]+)\s+<\/div>/)
      cb council + ': ' + result[1]

# see: http://stackoverflow.com/questions/164979/uk-postcode-regex-comprehensive/17507615#17507615
# modified to accept partial postcodes
isValidPostcode = (postcode) ->
  postcode.match(/^(([gG][iI][rR] {0,}0[aA]{2})|((([a-pr-uwyzA-PR-UWYZ][a-hk-yA-HK-Y]?[0-9][0-9]?)|(([a-pr-uwyzA-PR-UWYZ][0-9][a-hjkstuwA-HJKSTUW])|([a-pr-uwyzA-PR-UWYZ][a-hk-yA-HK-Y][0-9][abehmnprv-yABEHMNPRV-Y])))( [0-9][abd-hjlnp-uw-zABD-HJLNP-UW-Z]{2})?))$/)

