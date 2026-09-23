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
use Scalar::Util qw( looks_like_number );

use Kahifu::Junbi;
use Kahifu::Template qw{dict};
use Kahifu::Setuzoku;

sub settei_syutoku {
    my $lang = shift//'nihongo';
    my $settei_file = "/var/www/html/yanagi/nakaniwa/${lang}_colle.json";
	my $settei_text = do {
		open(my $api_fh, "<:encoding(UTF-8)", $settei_file)
			or die("Cannot open \"$settei_file\": $!\n");
		local $/;
		<$api_fh>
	};
	my $json_settei = JSON->new;
	return my $settei_json_data = $json_settei->decode($settei_text);
}

sub settei_kakikomu {
    my $settei_json_data = shift;
    my $lang = shift//'nihongo';
    my $settei_file = "/var/www/html/yanagi/nakaniwa/${lang}_colle.json";
    open(my $settei_fh, ">", $settei_file)
        or die("Cannot open \"$settei_file\": $!\n");
    print $settei_fh to_json($settei_json_data);
    close $settei_fh;
}

if(request_method eq 'POST' && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
    if(looks_like_number(param('reference'))){
        my $id = param('reference');
        my $midasi_kakunin = "select id, midasi, sakka, colle from sakuhin where id = ?";
        my $midasi_jikkou = $dbh->prepare($midasi_kakunin);
        $midasi_jikkou->execute($id);
        my $sakuhin_info = $midasi_jikkou->fetchall_hashref('id');
        my @sakuhin_colle = split ',', $sakuhin_info->{$id}{colle};
        if(grep{$_ eq 'kansyou_ja'} @sakuhin_colle){
            my $settei_json_data = settei_syutoku();
            $settei_json_data->{syutten} = "$sakuhin_info->{$id}{sakka}「$sakuhin_info->{$id}{midasi}」";
            settei_kakikomu($settei_json_data);
        } elsif (grep{$_ eq 'kansyou_en'} @sakuhin_colle){
            my $settei_json_data = settei_syutoku('english');
            $settei_json_data->{syutten} = "$sakuhin_info->{$id}{sakka}「$sakuhin_info->{$id}{midasi}」";
            settei_kakikomu($settei_json_data, 'english');
        }
    }
}

my $query=new CGI;
print $query->redirect($ENV{HTTP_REFERER});
print "Content-type: text/html; charset=utf-8\n\n";