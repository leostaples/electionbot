# Description:
#   Election results bot
#
# Todo:
#   council/general election query
#   find mp/twitter handle (csv) - juicer get hansard
#   local constituency news, hansard etc.
#   error handling if no council/no results
#   parliament api - full bio
#   use LDP lookup? (gssid->guid), get creativeworks about council/constituency
#   heroku/cert, locator api key?
#   rewrite in pure js (hate coffescript)

fs = require('fs')
https = require("https")
csv = require("fast-csv");

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
    console.log "postcode #{postcode}"

    if isValidPostcode postcode
      console.log "valid postcode"
      postcode = postcode.replace(' ','%20')
      path = "/locator/locations/#{postcode}/details/gss-council" #TODO: allow gss-seat queries for general election results

      getLocation msg, path, getElectionResult, (response) ->
        msg.send response
    else
      console.log "invalid postcode"
      msg.send "Sorry but that is not valid postcode."

  robot.respond /mp (.*)/i, (msg) ->
    postcode = msg.match[1]
    console.log "postcode #{postcode}"

    if isValidPostcode postcode
      console.log "valid postcode"
      postcode = postcode.replace(' ','%20')
      path = "/locator/locations/#{postcode}/details/gss-seat"

      getLocation msg, path, getMP, (response) ->
        msg.send response
    else
      console.log "invalid postcode"
      msg.send "Sorry but that is not valid postcode."

getLocation = (msg, path, cb1, cb2) ->
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
        name = nearest.data.geographyName
        gssid = nearest.externalId

        cb1 msg, name, gssid, cb2
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

getMP = (msg, seat, gssid, cb) ->
  console.log "getting MP for #{seat}"

  seat = seat.replace(' Boro Const','')

  members = {}

  csv.fromPath("/Users/leostaples/Sites/electionbot/data/mp_twitter_accounts.csv",
    headers: true
  ).on("data", (data) ->
    members[data.constituency] = data
    return
  ).on "end", ->
    console.log "done", members[seat].twitter_handle
    twitter = members[seat].twitter_handle
    twitter = twitter.replace('https://twitter.com/','@')
    cb "Your MP is #{twitter}"
    return


# see: http://stackoverflow.com/questions/164979/uk-postcode-regex-comprehensive/17507615#17507615
# modified to accept partial postcodes
isValidPostcode = (postcode) ->
  postcode.match(/^(([gG][iI][rR] {0,}0[aA]{2})|((([a-pr-uwyzA-PR-UWYZ][a-hk-yA-HK-Y]?[0-9][0-9]?)|(([a-pr-uwyzA-PR-UWYZ][0-9][a-hjkstuwA-HJKSTUW])|([a-pr-uwyzA-PR-UWYZ][a-hk-yA-HK-Y][0-9][abehmnprv-yABEHMNPRV-Y])))( [0-9][abd-hjlnp-uw-zABD-HJLNP-UW-Z]{2})?))$/)

