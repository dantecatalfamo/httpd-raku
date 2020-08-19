#!/usr/bin/env raku

grammar RequestGrammar {
    token TOP { <site><space><ip><notsure><timestamp><space><quote><request><quote><space><status><space><transfer><space><quote><referrer><quote><space><quote><useragent><quote> .* }
    token site { <[\w\.]>+ }
    token space { \s+ }
    token ip { <[\d\.]>+ }
    token notsure { ' - - ' }
    token timestamp { '[' <day> '/' <month> '/' <year> ':' <hour> ':' <minute> ':' <second> ' ' <timezone> ']' }
    token day { \d+ }
    token month { \w+ }
    token year { \d+ }
    token hour { \d\d }
    token minute { \d\d }
    token second { \d\d }
    token timezone { <[\+\-]> \d\d\d\d }
    token request { <method> ' ' <path> ' ' <version> }
    token method { \w+ }
    token path { \S+ }
    token version { <[\w\.\/]>+ }
    token status { \d+ }
    token transfer { \d+ }
    token quote { '"' }
    token referrer { <-["]>* }
    token useragent { <-["]>* }
}

class Request {
    has Str $.site;
    has Str $.ip;
    has Str $.timestamp;
    has Str $.method;
    has Str $.path;
    has Str $.request;
    has Int $.status;
    has Int $.transfer;
    has Str $.referrer;
    has Str $.useragent;
}

constant $log = "/var/www/logs/access.log".IO;
constant $site = "blog.lambda.cx";

my @spinner = '|', '/', '-', '\\';
my $spinners = @spinner.elems;

sub spin($c) {
    state $count = 0;
    $count++;
    $count %= $spinners;
    print("\r{@spinner[$count]} $c lines parsed");
}

sub MAIN(
    Bool :$i,      #= Show IP statistics
    Bool :$p,      #= Show path statistics
    Bool :$u,      #= Show User-Agent statistics
    Bool :$r,      #= Show Referrer statistics
    Bool :$m,      #= Only show statistics on User-Agents starting with "Mozilla/5.0"
    Bool :$f,      #= Only show foreign referrers
    Int :$n = 25,  #= Number of top positions to show for each stat
) {
    my @requests;

    my $begin = now;
    for $log.lines -> $line {
        my $parsed = RequestGrammar.parse($line);
        next if !$parsed;
        my $request = Request.new(
            site => ~$parsed<site>,
            ip => ~$parsed<ip>,
            timestamp => ~$parsed<timestamp>,
            method => ~$parsed<request><method>,
            path => ~$parsed<request><path>,
            request => ~$parsed<request>,
            status => +$parsed<status>,
            transfer => +$parsed<transfer>,
            referrer => ~$parsed<referrer>,
            useragent => ~$parsed<useragent>,
        );
        state $count = 0;
        spin($count) if ++$count %% 100;
        @requests.push($request);
    }

    say "\n{@requests.elems}";
    my $taken = now - $begin;
    my $rate = $taken / @requests.elems;
    printf("Time: %f.2\nPer: %f.5\nRate: %f.2/second", $taken, $rate, 1/$rate);

    my %agents;
    my %paths;
    my %ips;
    my %refs;

    for @requests {
        next if $m && !$_.useragent.starts-with("Mozilla/5.0");
        %agents{$_.useragent}++ if $u.defined;
        %paths{$_.path}++ if $p.defined;
        %ips{$_.ip}++ if $i.defined;
        %refs{$_.referrer}++ if $r.defined && !$_.referrer.contains($site)
    };

    if $u {
        say "User-Agents:";
        for %agents.sort(-*.value).head($n) {
            my $ua = $_.key;
            my $n = $_.value;
            say "$n: $ua";
        }
    }

    if $p {
        say "Paths:";
        for %paths.sort(-*.value).head($n) {
            my $p = $_.key;
            my $n = $_.value;
            say "$n: $p";
        }
    }

    if $i {
        say "IPs:";
        for %ips.sort(-*.value).head($n) {
            my $ip = $_.key;
            my $n = $_.value;
            say "$n: $ip";
        }
    }

    if $r {
        say "Referrers:";
        for %refs.sort(-*.value).head($n) {
            my $ref = $_.key;
            my $n = $_.value;
            say "$n: $ref";
        }
    }
}
