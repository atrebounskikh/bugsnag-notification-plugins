nodemailer           = require('nodemailer')
mustache             = require('mustache')
fs                   = require('fs')
notification_require = require "../"

# Set up nodemailer
nodemailer.sendmail = true

# Load a mustache template from a file in the templates directory
loadTemplate = (file) ->
    try
        fs.readFileSync require('path').join(__dirname, "templates", file), "utf-8"
    catch err
        console.log "Email: error reading template: #{err}"

# Load the templates
plainTemplate = loadTemplate "error.plain.mustache"
htmlTemplate  = loadTemplate "error.html.mustache"

class exports.Notification extends notification_require.NotificationBase
    
    # Notifier
    executeNotification: (callback) =>
        # Make variables available in templates
        @projectHandle.fetch (err, project) =>
            return callback(err) if err?
            @errorUrl (err, url) =>
                return callback(err) if err?
                @trigger.getLongExplanation (explanation) =>
                    context =
                        eventClass: @event.exceptions[0].errorClass
                        eventContext: @event.context
                        eventMessage: @event.exceptions[0].message
                        eventTrace: @event.exceptions[0].stacktrace
                        projectName: project.name
                        url: url
                        explanationText: explanation
            
                    for line in @event.exceptions[0].stacktrace
                        if line.inProject
                            context.inProjectStack = line
                            break
        
                    @emailAddresses (err, emails) =>
                        return callback "Error when retrieving emails! Contents: #{err}" if err?
            
                        for email in emails
                            do (email) =>
                                # Send the email
                                nodemailer.send_mail {
                                    to : email
                                    subject : "[#{context.projectName}] - #{context.eventClass} : #{ if context.eventContext != "" then context.eventContext else context.eventMessage }"
                                    sender: 'Bugsnag <noreply@bugsnag.com>'
                                    body: mustache.to_html plainTemplate, context
                                    html: mustache.to_html htmlTemplate, context
                                }, (err, result) ->
                                    return callback "NotificationEmail: error sending email: #{err}" if err?