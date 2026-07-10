use scripting additions

on run argv
  if (count of argv) is less than 5 then
    error "Usage: send_morning_brief_email.applescript <brief_path> <brief_date> <body_path> <sender> <recipient> [recipient...]"
  end if

  set briefPath to item 1 of argv
  set briefDate to item 2 of argv
  set bodyPath to item 3 of argv
  set senderAddress to item 4 of argv
  set recipientItems to items 5 thru -1 of argv
  set briefFile to POSIX file briefPath
  set subjectLine to "科研晨间简报 - " & briefDate
  set bodyText to do shell script "/bin/cat " & quoted form of bodyPath

  tell application "Mail"
    activate
    set outgoingMessage to make new outgoing message with properties {visible:false, subject:subjectLine, content:bodyText}
    tell outgoingMessage
      set sender to senderAddress
      repeat with recipientAddress in recipientItems
        make new to recipient at end of to recipients with properties {address:(recipientAddress as text)}
      end repeat
      make new attachment with properties {file name:briefFile} at after last paragraph
      send
    end tell
  end tell
end run
