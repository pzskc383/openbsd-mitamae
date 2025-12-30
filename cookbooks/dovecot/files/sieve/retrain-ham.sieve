require ["copy", "environment", "imapsieve", "variables", "vnd.dovecot.pipe"];
require ["vnd.dovecot.debug"];


if environment :matches "imap.mailbox" "*" {
	set "box" "${0}";
}

if not string :is "${box}" ["Junk", "Trash"] {
	debug_log "retrain-ham triggered: moving from ${box} to somewhere";
	pipe :copy "bogofilter-train" ["retrain"];
}