require ["variables", "envelope", "fileinto", "mailbox", "vnd.dovecot.environment"];

if environment :matches "user" "*@*" {
    set :lower "myname" "${1}";
}

if envelope :matches :localpart "to" "*" {
    set :lower "rcpt" "${1}";

    if not string :is "${rcpt}" "${myname}" {
        fileinto :create "catchall/${rcpt}";
        stop;
    }
}