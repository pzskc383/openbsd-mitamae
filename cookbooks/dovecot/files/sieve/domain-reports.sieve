require ["variables", "envelope", "fileinto", "subaddress", "mailbox"];

if envelope :is :user "to" "reports" {
    if envelope :matches :detail "to" "?*" {
        set :lower "type" "${1}";

        if string :is "${type}" "acme" {
            fileinto :create "reports/ACME";
        } elsif string :is "${type}" "tls" {
            fileinto :create "reports/TLS-RPT";
        } elsif string :is "${type}" "dmarc.a" {
            fileinto :create "reports/DMARC/Aggregate";
        } elsif string :is "${type}" "dmarc.f" {
            fileinto :create "reports/DMARC/Forensic";
        }
        stop;
    }
}
