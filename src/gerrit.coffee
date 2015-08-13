# Description:
#   Interact with Gerrit. (http://code.google.com/p/gerrit/)
#
# Dependencies:
#
# Configuration:
#   HUBOT_GERRIT_SSH_URL
#   HUBOT_GERRIT_SSH_PRIVATE_KEY
#
# Commands:
#   hubot search gerrit _<query>_ - Search Gerrit for changes (limited to 3 results)
#   hubot show gerrit updates for _event_  _(patchset-created|change-abandoned|change-restored|change-merged)_ - Subscribe active channel to Gerrit updates
#   hubot show gerrit updates for _(project|user)_  _<update>_ - Subscribe active channel to Gerrit updates
#   hubot remove gerrit updates for _(project|user|event)_  _<update>_ - Remove Gerrit update from active channel
#   hubot view gerrit subscriptions - View gerrit subscriptions for active channel
#
# Notes:
#   Hubot has to be running as a user who has registered a SSH key with Gerrit
#
# Authors:
#   nparry, justmiles

cp = require "child_process"
url = require "url"
mktemp = require "mktemp"
fs = require "fs"

# Required - The SSH URL for your Gerrit server.
sshUrl = process.env.HUBOT_GERRIT_SSH_URL || ""
# Required - The private key to connect to Gerrit (single line with \n)
privateKey = process.env.HUBOT_GERRIT_SSH_PRIVATE_KEY?.replace(/\\n/g, '\n') || ""

keyFile = mktemp.createFileSync "XXXXX.tmp"
fs.writeFileSync keyFile, privateKey

attachments =
  queryResult: (json) -> {
  "fallback": "'#{json.change.subject}' for #{json.change.project}/#{json.change.branch} by #{extractName json.change} on #{formatDate json.change.lastUpdated}",
  "title": "#{json.change.project} by #{extractName json.change}",
  "title_link": json.change.url,
  "text": json.change.subject,
  "fields": [
    {
      "title": "Branch",
      "value": json.change.branch,
      "short": true
    },
    {
      "title": "Date",
      "value": "#{formatDate json.change.lastUpdated}",
      "short": true
    }
  ]
  }
  events:
    "patchset-created": (json) -> {
    "fallback": "#{extractName json} uploaded patchset #{json.patchSet.number} of '#{json.change.subject}' for #{json.change.project}/#{json.change.branch}: #{json.change.url}",
    "title": "Commit Created in #{json.change.project}",
    "title_link": json.change.url,
    "color": "a6a6a6",
    "text": json.change.subject,
    "fields": [
      {
        "title": "Author",
        "value": "#{extractName json}",
        "short": true
      },
      {
        "title": "Branch",
        "value": json.change.branch,
        "short": true
      }
    ]
    }
    "change-abandoned": (json) -> {
    "fallback": "#{extractName json} abandoned '#{json.change.subject}' for #{json.change.project}/#{json.change.branch}: #{json.change.url}",
    "title": "Commit Abandoned in #{json.change.project}",
    "title_link": json.change.url,
    "color": "f30020",
    "text": json.change.subject,
    "fields": [
      {
        "title": "Abandoned by",
        "value": "#{extractName json}",
        "short": true
      },
      {
        "title": "Branch",
        "value": json.change.branch,
        "short": true
      }
    ]
    }
    "change-restored": (json) -> {
    "fallback": "#{extractName json} restored '#{json.change.subject}' for #{json.change.project}/#{json.change.branch}: #{json.change.url}",
    "title": "Commit Restored in #{json.change.project}",
    "title_link": json.change.url,
    "color": "#F35A00",
    "text": json.change.subject,
    "fields": [
      {
        "title": "Restored by",
        "value": "#{extractName json}",
        "short": true
      },
      {
        "title": "Branch",
        "value": json.change.branch,
        "short": true
      }
    ]
    }
    "change-merged": (json) -> {
    "fallback": "#{extractName json} merged  #{json.patchSet.number} of '#{json.change.subject}' for #{json.change.project}/#{json.change.branch}: #{json.change.url}",
    "title": "Commit Merged in #{json.change.project}",
    "title_link": json.change.url,
    "color": "#36a64f",
    "text": json.change.subject,
    "fields": [
      {
        "title": "Merged by",
        "value": "#{extractName json}",
        "short": true
      },
      {
        "title": "Branch",
        "value": json.change.branch,
        "short": true
      }
    ]
    }

formatters =
  queryResult:          (json) -> "'#{json.change.subject}' for #{json.change.project}/#{json.change.branch} by #{extractName json.change} on #{formatDate json.change.lastUpdated}: #{json.change.url}"
  events:
    "patchset-created": (json) -> "#{extractName json} uploaded patchset #{json.patchSet.number} of '#{json.change.subject}' for #{json.change.project}/#{json.change.branch}: #{json.change.url}"
    "change-abandoned": (json) -> "#{extractName json} abandoned '#{json.change.subject}' for #{json.change.project}/#{json.change.branch}: #{json.change.url}"
    "change-restored":  (json) -> "#{extractName json} restored '#{json.change.subject}' for #{json.change.project}/#{json.change.branch}: #{json.change.url}"
    "change-merged":    (json) -> "#{extractName json} merged patchset #{json.patchSet.number} of '#{json.change.subject}' for #{json.change.project}/#{json.change.branch}: #{json.change.url}"
    "comment-added":    (json) -> "#{extractName json} reviewed patchset #{json.patchSet.number} (#{extractReviews json}) of '#{json.change.subject}' for #{json.change.project}/#{json.change.branch}: #{json.change.url}"
    "ref-updated":      (json) -> "#{extractName json} updated reference #{json.refUpdate.project}/#{json.refUpdate.refName}"

formatDate = (seconds) ->
  timestamp = new Date(seconds * 1000);
  format = {hour: '2-digit', minute:'2-digit'}
  return "#{timestamp.toLocaleDateString()} #{timestamp.toLocaleTimeString('en-US', format)}";

asSet = (array) ->
  a = array.concat()
  i = 0
  while i < a.length
    j = i + 1
    while j < a.length
      if a[i] == a[j]
        a.splice j--, 1
      ++j
    ++i
  return a

extractName = (json) ->
  account = json.uploader || json.abandoner || json.restorer || json.submitter || json.author || json.owner
  account?.name || account?.email || "Gerrit"
extractReviews = (json) ->
  ("#{a.description}=#{a.value}" for a in json.approvals).join ","

module.exports = (robot) ->
  gerrit = url.parse sshUrl
  gerrit.port = 22 unless gerrit.port

  if gerrit.protocol != "ssh:" || gerrit.hostname == ""
    robot.logger.error "Gerrit commands inactive because HUBOT_GERRIT_SSH_URL=#{gerrit.href} is not a valid SSH URL"
  else if privateKey == ""
    robot.logger.error "Gerrit commands inactive because HUBOT_GERRIT_SSH_PRIVATE_KEY is not set"
  else
    eventStreamMe robot, gerrit
    robot.respond /(?:search|query)(?: me)? gerrit (.+)/i, searchMe robot, gerrit
    robot.respond /(show)(?: me)? gerrit updates for (project|user|event) (.+)/i, subscribeToEvents robot
    robot.respond /(remove)(?: me)? gerrit updates for (project|user|event) (.+)/i, deleteSubscription robot
    robot.respond /view gerrit subscriptions/i, showSubscriptions robot

searchMe = (robot, gerrit) -> (msg) ->
  cp.exec "ssh -i #{keyFile} #{gerrit.auth}@#{gerrit.hostname} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p #{gerrit.port} gerrit query --format=JSON -- #{msg.match[1]} limit:3", (err, stdout, stderr) ->
    if err
      msg.send "Sorry, something went wrong talking with Gerrit: ```#{stderr}```"
    else
      results = (JSON.parse l for l in stdout.split "\n" when l isnt "")
      status = results[results.length - 1]
      if status.type == "error"
        msg.send "Sorry, Gerrit didn't like your query: ```#{status.message}```"
      else if status.rowCount == 0
        msg.send "Gerrit didn't find anything matching your query"
      else
        if robot.adapterName == 'slack'
          for r in results when r.id
            robot.emit 'slack-attachment',
              message:
                room: msg.message.room
              content: attachments.queryResult change: r
        else
          msg.send formatters.queryResult change: r for r in results when r.id

showSubscriptions = (robot) -> (msg) ->
  hasSubscriptions = false
  show = (obj, type) ->
    for k,v of obj
      if typeof v == 'object'
        if v.indexOf(msg.message.room) != -1
          hasSubscriptions = true
          msg.send "#{msg.message.room} is subscribed to #{type} `#{k}`"

  show robot.brain.data.gerrit?.eventStream?.subscription?.user, 'user'
  show robot.brain.data.gerrit?.eventStream?.subscription?.event, 'event'
  show robot.brain.data.gerrit?.eventStream?.subscription?.project, 'project'

  if !hasSubscriptions
    msg.send "#{msg.message.room} has no subscriptions"

deleteSubscription = (robot) -> (msg) ->
  type = msg.match[2].toLowerCase()
  event = msg.match[3]
  subscribers = robot.brain.data.gerrit?.eventStream?.subscription?[type]?[event] || []
  index = subscribers.indexOf(msg.message.room)
  if index != -1
    subscribers.splice(index, 1);
    robot.brain.data.gerrit?.eventStream?.subscription?[type]?[event] = subscribers
    msg.send "#{msg.message.room} will no longer receive #{event} updates."
  else
    msg.send "#{msg.message.room} was never subscribed to #{event} updates"

subscribeToEvents = (robot) -> (msg) ->
  type = msg.match[2].toLowerCase()
  event = msg.match[3]
  subscribers = robot.brain.data.gerrit?.eventStream?.subscription?[type]?[event] || []
  subscribers.push msg.message.room

  robot.brain.data.gerrit ?= { }
  robot.brain.data.gerrit.eventStream ?= { }
  robot.brain.data.gerrit.eventStream.subscription ?= { }
  robot.brain.data.gerrit.eventStream.subscription[type] ?= { }
  robot.brain.data.gerrit.eventStream.subscription[type][event] = asSet subscribers

  msg.send "This channel has subscribed to Gerrit #{type} updates matching `#{event}`"

eventStreamMe = (robot, gerrit) ->
  robot.logger.info "Gerrit stream-events: Starting connection"
  streamEvents = cp.spawn "ssh", ["-i", keyFile, "-o", "UserKnownHostsFile=/dev/null", "-o", "StrictHostKeyChecking=no", "#{gerrit.auth}@#{gerrit.hostname}", "-p", gerrit.port, "gerrit", "stream-events"]
  done = false
  reconnect = null

  robot.brain.on "close", ->
    done = true
    clearTimeout reconnect if reconnect
    streamEvents.stdin.end()
  streamEvents.on "exit", (code) ->
    robot.logger.info "Gerrit stream-events: Connection lost (rc=#{code})"
    reconnect = setTimeout (-> eventStreamMe robot, gerrit), 10 * 1000 unless done

  getSubscribers = (robot, event) ->
    projectSubs = robot.brain.data.gerrit?.eventStream?.subscription?.project?[event.change.project] || []
    eventSubs   = robot.brain.data.gerrit?.eventStream?.subscription?.event?[event.type] || []
    userSubs    = robot.brain.data.gerrit?.eventStream?.subscription?.user?["#{extractName event}"] || []
    return asSet projectSubs.concat(eventSubs).concat(userSubs)

  streamEvents.stderr.on "data", (data) ->
    robot.logger.info "Gerrit stream-events: #{data}"

  streamEvents.stdout.on "data", (data) ->
    robot.logger.debug "Gerrit stream-events: #{data}"

    json = try
      JSON.parse data
    catch error
      robot.logger.error "Gerrit stream-events: Error parsing Gerrit JSON. Error=#{error}, Event=#{data}"
      null

    return unless json

    if robot.adapterName == 'slack'
      formatter = attachments.events[json.type]

    else
      formatter = formatter.events[json.type]

    msg = try
      formatter json if formatter
    catch error
      robot.logger.error "Gerrit stream-events: Error formatting event. Error=#{error}, Event=#{data}"
      null

    if formatter == null
      robot.logger.info "Gerrit stream-events: Unrecognized event #{data}"

    else if msg
      for room in getSubscribers(robot, json)
        if robot.adapterName == 'slack'
          robot.emit 'slack-attachment',
            message:
              room: room
            content: msg
        else
          robot.send room: room, "Gerrit: #{msg}" for room in robotRooms robot
