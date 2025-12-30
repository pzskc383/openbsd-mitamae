require ["copy", "environment", "imapsieve", "variables", "vnd.dovecot.pipe"];
require ["vnd.dovecot.debug"];

if environment :matches "imap.mailbox" "*" {
	set "box" "${0}";
}

debug_log "train-spam triggered: moving from ${box} to somewhere";

pipe :copy "bogofilter-train" ["spam"];