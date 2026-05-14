#!/usr/bin/perl
use strict;
use warnings;

use CGI ":standard";
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use lib qw(/var/www/html/heart/mod);
use Data::Dump qw(dump);
use DateTime;
use DBI;
use URI;
use JSON;
use open qw( :std :encoding(utf8) );
use utf8;
use Encode qw( decode_utf8 );
use POSIX;

use Kahifu::Junbi;
use Kahifu::Template qw{dict};
use Kahifu::Setuzoku;
use Hyouka::Infra qw(jyoukyou_settei midasi_settei sakka_settei date date_split url_get_tuke url_get_hazusi week week_border week_count week_delta hash_max_key timestamp_syutoku);
use Hyouka::External;

# Tautulli側
# Configuration
# 　Notification Agents>Webhook>Webhook URLはここ
# 　Webhook Method = POST
# Triggers
# 　WatchedとPlayback Stopを有効にする
# Data>Watched
# {"start": "{started_unixtime}", "end": "{unixtime}", "part": "{episode_num}","tmdb": "{themoviedb_id}", "show": "{season_num}x{episode_num00}", "title": "{title}", "syurui": "{media_type}", "id": "{parent_rating_key}","stream": "{session_id}", "mid": "{rating_key}","tuuti": "kansyouzumi"}
# Data>Playback Stop
#{"start": "{started_unixtime}", "end": "{unixtime}", "part": "{episode_num}", "tmdb": "{themoviedb_id}", "show": "{season_num}x{episode_num00}", "title": "{title}", "syurui": "{media_type}", "id": "{parent_rating_key}", "mid": "{rating_key}", "stream": "{session_id}","tuuti": "stop"}


if(request_method eq 'POST'){
    my $dbh = Kahifu::Setuzoku::sql('kangeiroku');

    my $query = CGI->new;
    my $data = from_json($query->param('POSTDATA'));

    my $start_jiten = $data->{start};
    my $end_jiten = $data->{end};
    my $part = $data->{part};
    my $tmdb = $data->{tmdb};
    my $show = $data->{show};
    my $title = $data->{title};
    my $syurui = $data->{syurui};
    my $tuuti = $data->{tuuti};
    my $stream = $data->{stream};
    my $pid = !defined $data->{id} || $data->{id} eq '' ? $data->{mid} : $data->{id};
	
    my $memo = $title . "→" . $show . "($syurui)";
    $part = $syurui eq "movie" && $part + 0 == 0 ? 1 : $part;

    my $sid = undef;
    my $soutei_rireki = $dbh->prepare("select sid from `tautulli_match` where pid = ? limit 1");
    $soutei_rireki->execute($pid);
    while(my $v = $soutei_rireki->fetchrow_hashref){
        $sid = $v->{sid};
    }

    my $sousin = $query->param('POSTDATA');

    if($tuuti eq 'stop'){
        my $meirei = "update tautulli set jiten = ?, stop = 1 where stream = ? and pid = ? and status = 0";
        my $sakuhin_insert = $dbh->prepare($meirei);
	    $sakuhin_insert->execute($end_jiten, $stream, $pid);
    } else {
        my $meirei = "insert into tautulli set sid = ?, pid = ?, start = ?, jiten = ?, part = ?, status = 0, memo = ?, stream = ?, stop = 0";
        my $sakuhin_insert = $dbh->prepare($meirei);
	    $sakuhin_insert->execute($sid, $pid, $start_jiten, $end_jiten, $part, $memo, $stream);
    }
}

my $query=new CGI;
print $query->redirect("https://kahifu.net/chronicle/default.pl");
print "Content-type: text/html; charset=utf-8\n\n";