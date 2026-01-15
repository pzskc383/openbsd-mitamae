require "imap4flags";
require "regex";

if anyof (
    exists "X-Cron-Env",
    header :regex ["subject"] [".* security run output", ".* monthly run output", ".* daily run output", ".* weekly run output"]
)
{ addflag "\\Flagged"; }
