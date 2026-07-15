#!/usr/bin/perl
use strict;
use warnings;

use open qw( :std :encoding(utf8) );
use utf8;
use CGI ":standard";
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use lib qw(/var/www/html/heart/mod);

use Kahifu::Junbi;
use Kahifu::Template qw{dict};
use Hyouka::Infra qw(config_syutoku date);

my $uri = Kahifu::Template::fetch_uri(__FILE__);
my $ami = Kahifu::Template::fetch_ami($uri);

my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
my %cookie = CGI::Cookie->fetch;
my $query = CGI->new;
my %url_get = $query->Vars();

our $ninsyou = (defined $cookie{kangeiroku_ninsyou} && unpack('H*', sha256($cookie{kangeiroku_ninsyou})) == Kahifu::Key::hyouka_sesame) || Kahifu::Template::tenmei;

our $config = config_syutoku();
our $style = (defined $cookie{hyouka_style}) ? $cookie{hyouka_style}->value : $config->{style};

print "Content-type: text/html\n\n";

print Kahifu::Template::html_header($ami);
print "<link rel=\"stylesheet\" href=\"/chronicle/style/sumi.css\" />";
print "<link rel=\"stylesheet\" href=\"/chronicle/style/";
print $style;
print ".css\" />";
print "<link rel=\"stylesheet\" href=\"/chronicle/style/koten.css\" />";
print "<link rel=\"stylesheet\" href=\"/chronicle/style/keitai.css\" />" if Kahifu::Infra::mobile();
print Kahifu::Template::html_saki("${\(Kahifu::Template::dict('HYOUKA_TITLE'))}<span>${\(Kahifu::Template::dict('EIGOYOU_KUUHAKU'))}${\(Kahifu::Template::dict('HYOUKA_SUBTITLE'))}</span>", undef, "Hyouka");

sub syurui {
    my $syurui = shift//0;
    my $mode = shift//0;
    my $syurui_list = [
        'シングル',
        'アルバム',
        'サウンドトラック',
        'ベストアルバム',
        'シングル集',
        'カバーアルバム',
        'アレンジアルバム',
        '非公式アルバム',
        'オムニバスアルバム',
        'ライブアルバム'
    ];
    $syurui_list = [
        '☆',
        '★',
        '✿',
        '■',
        '◇',
        '▲',
        '△',
        '▼',
        '▽',
        '☗'
    ] if $mode == 1;
    return $syurui_list->[$syurui];
}

sub media {
    my $media = shift//0;
    my $media_list = [
        '12cm',
        '8cm'
    ];
    return $media_list->[$media];
}

sub jyou {
    my $jyou = shift//0;
    my $jyou_list = [
        '優', '甲', '乙', '丙', '丁', '戊', '己', '庚'
    ];
    return $jyou_list->[$jyou];
}

if(defined param('rip')){
    my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
    my $catalog1 = param('catalog1');
    my $catalog2 = param('catalog2');
    my $rip_kousin_query = "update `record` set ripzumi = 1 - ripzumi where `catalog1` = ? and `catalog2` = ?";
	my $rip_kousin = $dbh->prepare($rip_kousin_query);
	$rip_kousin->execute($catalog1, $catalog2);
}

# html>enter
print "<div class='record'>";
    print "<div class='info'>";
        print "<div class='title'>";
            print "タイトル";
        print "</div>";
        print "<div class='artist'>";
            print "アーティスト";
        print "</div>";
        print "<div class='date'>";
            print "発売日";
        print "</div>";
        print "<div class='grade'>";
            print "状";
        print "</div>";
    print "</div>";

    my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
    if(defined param('mkdir')){
        my $record = $dbh->prepare("select *, concat(coalesce(catalog1, ''), '-', coalesce(catalog2, '')) as catalog from record group by catalog");
        $record->execute();
        while(my $v = $record->fetchrow_hashref){
            my $date_seisiki = defined $v->{date} && $v->{date} ne '' ? length $v->{date} == 8 ? substr($v->{date}, 0, 4) . '.' . substr($v->{date}, 4, 2) . '.' . substr($v->{date}, 6, 2) : (length $v->{date} == 6 ? substr($v->{date}, 0, 4) . '.' . substr($v->{date}, 4, 2) . '.' . 'xx' : (length $v->{date} == 4 ? substr($v->{date}, 0, 4) . '.' . 'xx' . '.' . 'xx' : undef ) ) : undef;
            my $date_sounyuu = defined $date_seisiki ? "[$date_seisiki] " : '';
            print 'mkdir "';
            print "${date_sounyuu}${\(syurui($v->{syurui}, 1))}${\(defined $v->{artist} && $v->{artist} ne '' ? (defined $v->{top} && $v->{top} ne '' ? $v->{top} . ' - ' : $v->{artist} . ' - ') : undef)}${\(defined $v->{top2} && $v->{top2} ne '' ? $v->{top2} : (defined $v->{title} && $v->{title} ne '' ? (defined $v->{cw} && $v->{cw} ne '' ? $v->{title} . '／' . $v->{cw} : $v->{title} ) : '題名なし'))}${\(defined $v->{catalog1} && defined $v->{catalog2} && $v->{catalog1} ne '' && $v->{catalog2} ne '' ? ' {' . $v->{catalog1} . '-' . $v->{catalog2} . '}' : (defined $v->{catalog1} && $v->{catalog1} ne '' ? ' {' . $v->{catalog1} . '}' : undef))}";
            print '";';
            print "<br>";
        }
        exit;
    }

    my $record = $dbh->prepare("select * from record");
    $record->execute();
    while(my $v = $record->fetchrow_hashref){
        print "<div class='gyou'>";
            print "<div class='title rip_${\($v->{ripzumi} or 0)}'>";
                print "<span>";
                print $v->{title};
                print "<span class='coupling'>／" . $v->{cw} . "</span>" if $v->{cw} ne '';
                print "</span>";
                print "<form method='post'>";
                print "<input type='hidden' name='catalog1' value='$v->{catalog1}'>";
                print "<input type='hidden' name='catalog2' value='$v->{catalog2}'>";
                print "<input type='submit' name='rip' value='リッピ状トグル'>";
                print "</form>";
            print "</div>";
            print "<div class='artist'>";
                print $v->{artist};
            print "</div>";
            print "<div class='date'>";
                print defined $v->{date} ? date($v->{date}, 0, 0, 0) : '';
                print "<span name='hinban'>${\(defined $v->{catalog1} && defined $v->{catalog2} && $v->{catalog1} ne '' && $v->{catalog2} ne '' ? $v->{catalog1} . '-' . $v->{catalog2} : (defined $v->{catalog1} && $v->{catalog1} ne '' ? $v->{catalog1} : undef))}</span>";
            print "</div>";
            print "<div class='grade'>";
                print "<span class='jyou_$v->{jyou}'>", jyou($v->{grade}), "</span>";
            print "</div>";
        print "</div>";
    }
print "</div>";

print "<style>
div.record > div.gyou {
    display: flex;
    border-bottom: 1px solid black;
}

div.record > div > div.title {
    flex-basis: 55%;
    width: 55%;
    font-weight: bold;
}

div.record > div > div.title > span > span.coupling {
    opacity: 0.5;
}

div.record > div > div.title.rip_0 {
    color: #507895;
}

div.record > div > div.title.rip_1 {
    color: #b34a45;
}

div.record > div > div.artist {
    flex-basis: 20%;
    width: 20%;
}

div.record > div > div.date {
    flex-basis: 20%;
    width: 20%;
}

div.record > div > div.grade {
    flex-basis: 5%;
    width: 5%;
}

div.record > div > div.grade > span[class^=jyou_] {
    padding: 0 0.125em;
}

div.record > div > div.grade > span.jyou_0 {
    border: 1px dotted gray;
}

div.record > div > div.grade > span.jyou_1 {
    border: 1px solid lightgray;
}

div.record > div > div.grade > span.jyou_2 {
    border: 1px solid black;
    background-color: lightgray;
}

div.record > div > div.grade > span.jyou_3 {
    border: 1px dotted brown;
}

div.record > div > div.grade > span.jyou_4 {
    border: none;
}

div.record > div > div.grade > span.jyou_5 {
    opacity: 0.5;
}

input[name=rip] {
    display: none;
}

div.title {
    position: relative;
}

input[name=rip] {
    position: absolute;
    right: 0;
    top: 0px;
    bottom: 1px;
    background: linear-gradient(90deg, transparent 0%, #fff 30%);
    border: 0;
    font-family: inherit;
    font-size: inherit;
    font-weight: bold;
    color: red;
    line-height: 1;
    vertical-align: top;
}

div.gyou:hover input[name=rip] {
    display: block;
}

input[name=rip]:hover {
    color: yellow;
    text-shadow: 1px 1px blue, -1px -1px blue, -1px 1px blue, 1px -1px blue;
}

span[name=hinban] {
    display: none;
}

div.date {
    position: relative;
}

span[name=hinban] {
    position: absolute;
    right: 0;
    top: 0px;
    background: linear-gradient(90deg, transparent 0%, #fff 30%);
    border: 0;
    font-family: inherit;
    font-size: inherit;
    font-weight: bold;
    color: blue;
    vertical-align: top;
}

div.gyou:hover span[name=hinban] {
    display: block;
}
</style>";

# html>exeunt
print Kahifu::Template::html_noti();