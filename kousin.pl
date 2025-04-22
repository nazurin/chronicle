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

#print "Content-type: text/html; charset=utf-8\n\n";

if(request_method eq 'POST' && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
	#my %cookie = CGI::Cookie->fetch;
	#my $query = CGI->new;
	#my @title_post = $query->param;
	#print dump @title_post;
	my $passthrough_id = param('reference');
	my $info_sitami_query = "select count(*) as count, sid from rireki where sid = ? order by jiten desc limit 1";
	my $info_sitami_syutoku = $dbh->prepare($info_sitami_query);
	$info_sitami_syutoku->execute($passthrough_id);
	my $info_sitami = $info_sitami_syutoku->fetchall_hashref('sid');

	my ($info_query, $info_syutoku, $info);
	if($info_sitami->{$passthrough_id}{count} == 0){
		#右から試して
		$info_query = "select saku.id as ssid, reki.*, saku.whole as `sakuwhole`, saku.hajimari as `sakuhajimari`, saku.josuu as `sakujosuu`, saku.yotei as `yotei`, saku.jyoukyou as `sakujyoukyou`, saku.eternal as `eternal` from rireki reki right join sakuhin saku on reki.sid = saku.id where saku.`id` = ? order by jiten desc limit 1";
		$info_syutoku = $dbh->prepare($info_query);
		$info_syutoku->execute(param('reference'));
		$info = $info_syutoku->fetchall_hashref('ssid');
	} else {
		$info_query = "select reki.*, saku.whole as `sakuwhole`, saku.hajimari as `sakuhajimari`, saku.josuu as `sakujosuu`, saku.yotei as `yotei`, saku.jyoukyou as `sakujyoukyou`, saku.eternal as `eternal` from rireki reki left join sakuhin saku on reki.sid = saku.id where saku.`id` = ? order by jiten desc limit 1";
		$info_syutoku = $dbh->prepare($info_query);
		$info_syutoku->execute(param('reference'));
		$info = $info_syutoku->fetchall_hashref('sid');
	}
	#die dump $info;
	
	my $hajimari = param('tosi_hajimari').param('tuki_hajimari').param('hi_hajimari').param('ji_hajimari').param('fun_hajimari') ne "" ? timestamp_syutoku(param('tosi_hajimari'), param('tuki_hajimari'), param('hi_hajimari'), param('ji_hajimari'), param('fun_hajimari')) : (param('unix_hajimari') ne '' ? param('unix_hajimari') : $info->{$passthrough_id}{sakuhajimari});
	my $owari = param('tosi_owari').param('tuki_owari').param('hi_owari').param('ji_owari').param('fun_owari') ne "" ? timestamp_syutoku(param('tosi_owari'), param('tuki_owari'), param('hi_owari'), param('ji_owari'), param('fun_owari')) : (param('unix_owari') ne '' ? param('unix_owari') : time());
	my $josuu = decode_utf8(param('josuu')) eq '儘' ? $info->{$passthrough_id}{sakujosuu} : decode_utf8(param('josuu'));
	my $text = decode_utf8(param('title'));
	
	sub update_futuu {
		# 履歴に追加（part→変、whole→どちらも、状況→変、助数→儘）
		# 作品を更新（状況、part、whole、始まり、終わり）
		# 条件：part＜＝whole、part＞前part、時点＞前時点、前状況は…≠終・再・没
		my $jyoukyou = "中";
		$jyoukyou = "積" if param('mode') == 1;
		$jyoukyou = "落" if param('mode') == 2;
		$jyoukyou = "終" if param('part') == param('whole');
		my $text = decode_utf8(param('title'));
		my $josuu = param('josuu') == '儘' ? (defined $info->{$passthrough_id}{josuu} ? $info->{$passthrough_id}{josuu} : $info->{$passthrough_id}{sakujosuu}) : param('josuu');
		my $rireki_tuika_query = "insert into `rireki` set sid = ?, jiten = ?, part = ?, whole = ?, jyoukyou = ?, josuu = ?, mkt = ?, text = ?";
		my $rireki_tuika = $dbh->prepare($rireki_tuika_query);
		$rireki_tuika->execute(param('reference'), $owari, param('part'), param('whole'), $jyoukyou, $josuu, param('jikoku_mikakutei'), $text);
		my $sakuhin_kousin_query = "update sakuhin set yotei = 0, jyoukyou = ?, part = ?, whole = ?, hajimari = ?, owari = ? where id = ?";
		my $sakuhin_kousin = $dbh->prepare($sakuhin_kousin_query);
		$sakuhin_kousin->execute($jyoukyou, param('part'), param('whole'), $hajimari, $owari, param('reference'));
	}
	
	sub update_saikansyou {
		# 条件：前part = whole & mode=再 OR 前行＝再
		# 落・積→没、中→再
		my $jyoukyou = "再";
		$jyoukyou = "没" if param('mode') == 1 or param('mode') == 2;
		$jyoukyou = "終" if param('part') == param('whole');
		my $josuu = param('josuu') eq '儘' ? (defined $info->{$passthrough_id}{josuu} ? $info->{$passthrough_id}{josuu} : $info->{$passthrough_id}{sakujosuu}) : decode_utf8(param('josuu'));
		my $rireki_tuika_query = "insert into `rireki` set sid = ?, jiten = ?, part = ?, whole = ?, jyoukyou = ?, josuu = ?, mkt = ?, text = ?";
		my $rireki_tuika = $dbh->prepare($rireki_tuika_query);
		$rireki_tuika->execute(param('reference'), $owari, param('part'), param('whole'), $jyoukyou, $josuu, param('jikoku_mikakutei'), $text);
		my $sakuhin_kousin_query = "update sakuhin set yotei = 0, jyoukyou = ?, part = ?, whole = ?, hajimari = ?, owari = ? where id = ?";
		my $sakuhin_kousin = $dbh->prepare($sakuhin_kousin_query);
		$sakuhin_kousin->execute($jyoukyou, param('part'), param('whole'), $hajimari, $owari, param('reference'));
	}
	
	sub update_futakousin {
		# 前の行を更新する（終→中）
		# 条件：前part = whole & 助数詞＝前助数詞
		# 再鑑賞は当てはまらない→33/33から35/40になるには進行中の状態が必然…（ダブルバックトレース不要）
		my $rireki_backtrace_query = "update rireki set jyoukyou = ? where `id` = ? order by jiten desc limit 1";
		my $rireki_backtrace = $dbh->prepare($rireki_backtrace_query);
		$rireki_backtrace->execute('中', $info->{$passthrough_id}{id});
	}
	
	sub update_backtrace_part_error {
		#　条件：part<前part OR mode＝積・落 & part<=前part、whole=前whole、前part≠前whole、助数詞＝前助数詞
		#　更新：rireki→part、mkt、title（空ではないと）sakuhin→part、hajimari
		my $jyoukyou = "中";
		$jyoukyou = "積" if param('mode') == 1;
		$jyoukyou = "落" if param('mode') == 2;
		$jyoukyou = "再" if grep{$_ eq $info->{$passthrough_id}{sakujyoukyou}} '再', '没';
		$jyoukyou = "没" if grep{$_ eq $info->{$passthrough_id}{sakujyoukyou}} '再', '没' && (param('mode') == 1 || param('mode') == 2);
		$jyoukyou = "終" if param('part') == param('whole');
		
		my (@sitazi_bind, $text_sitazi);
		if($text ne ""){
			$text_sitazi = "text = ?,";
			push @sitazi_bind, ($text);
		}
		
		my $rireki_backtrace_query = "update rireki set ${text_sitazi} part = ?, mkt = ?, jyoukyou = ? where `id` = ? order by jiten desc limit 1";
		my $rireki_backtrace = $dbh->prepare($rireki_backtrace_query);
		$rireki_backtrace->execute(@sitazi_bind, param('part'), param('jikoku_mikakutei'), $jyoukyou, $info->{$passthrough_id}{id});
		if(param('mode') == 1 || param('mode') == 2){
			my $sakuhin_kousin_query = "update sakuhin set yotei = 0, jyoukyou = ? where id = ?";
			my $sakuhin_kousin = $dbh->prepare($sakuhin_kousin_query);
			$sakuhin_kousin->execute($jyoukyou, param('reference'));
		}
	}
	
	sub update_special_jyou {
		# 状況＝葉・飛（作品に映らない助数たち）	
		my $jyoukyou;
		$jyoukyou = "飛" if param('mode') == 4;
		$jyoukyou = "葉" if param('mode') == 5;
		my $rireki_tuika_query = "insert into `rireki` set sid = ?, jiten = ?, part = ?, whole = ?, jyoukyou = ?, josuu = ?, mkt = ?, text = ?";
		my $rireki_tuika = $dbh->prepare($rireki_tuika_query);
		$rireki_tuika->execute(param('reference'), $owari, param('part'), param('whole'), $jyoukyou, $josuu, param('jikoku_mikakutei'), $text);
		my $sakuhin_kousin_query = "update sakuhin set yotei = 0, part = ?, whole = ?, hajimari = ?, owari = ? where id = ?";
		my $sakuhin_kousin = $dbh->prepare($sakuhin_kousin_query);
		$sakuhin_kousin->execute(param('part'), param('whole'), $hajimari, $owari, param('reference'));
	}
	
	sub update_special_jyou_futakousin {
		# 状況＝葉・飛（作品に映らない助数たち）	
		# futakousinの場合
		my $jyoukyou;
		$jyoukyou = "飛" if param('mode') == 4;
		$jyoukyou = "葉" if param('mode') == 5;
		my $josuu = param('josuu') eq '儘' ? $info->{$passthrough_id}{josuu} : param('josuu');
		my $rireki_tuika_query = "insert into `rireki` set sid = ?, jiten = ?, part = ?, whole = ?, jyoukyou = ?, josuu = ?, mkt = ?, text = ?";
		my $rireki_tuika = $dbh->prepare($rireki_tuika_query);
		$rireki_tuika->execute(param('reference'), $owari, param('part'), param('whole'), $jyoukyou, $josuu, param('jikoku_mikakutei'), $text);
		$jyoukyou = "中";
		$jyoukyou = "終" if param('part') == param('whole');
		my $sakuhin_kousin_query = "update sakuhin set yotei = 0, jyoukyou = ?, part = ?, whole = ?, hajimari = ?, owari = ? where id = ?";
		my $sakuhin_kousin = $dbh->prepare($sakuhin_kousin_query);
		$sakuhin_kousin->execute($jyoukyou, param('part'), param('whole'), $hajimari, $owari, param('reference'));
	}
	
	sub update_josuu_all {
		# 助数詞≠前助数詞、part&whole=前part&whole
		my $rireki_kousin_query = "update `rireki` set josuu = ? where sid = ?";
		my $rireki_kousin = $dbh->prepare($rireki_kousin_query);
		$rireki_kousin->execute(param('josuu'), param('reference'));
		my $sakuhin_kousin_query = "update sakuhin set josuu = ?, hajimari = ? where id = ?";
		my $sakuhin_kousin = $dbh->prepare($sakuhin_kousin_query);
		$sakuhin_kousin->execute(param('josuu'), $hajimari, param('reference'));
	}
	
	sub update_hajimari {
		my $sakuhin_kousin_query = "update sakuhin set hajimari = ? where id = ?";
		my $sakuhin_kousin = $dbh->prepare($sakuhin_kousin_query);
		$sakuhin_kousin->execute($hajimari, param('reference'));
	}
	
	if(not defined param('sakujyo')){
		# 削除ではない場合
		if(($info->{$passthrough_id}{part} < param('part') || ($info->{$passthrough_id}{part} != param('part') && $info->{$passthrough_id}{josuu} != $josuu) || ($info->{$passthrough_id}{part} == 0 && $info->{$passthrough_id}{count} == 0) || ($info->{$passthrough_id}{part} == param('part') && $info->{$passthrough_id}{text} ne decode_utf8(param('title')))) && param('part') <= param('whole') && not (grep{$_ eq $info->{$passthrough_id}{sakujyoukyou}} '終', '再', '没') && not (grep{$_ eq param('mode')} 4, 5)){
			#print 'Yes!'; #update_futuu
			update_futuu();
		} elsif ($info->{$passthrough_id}{part} == $info->{$passthrough_id}{whole} && (($info->{$passthrough_id}{whole} != param('whole') && $info->{$passthrough_id}{josuu} != $josuu) || ($info->{$passthrough_id}{whole} < param('whole'))) && not param('mode') == 5){
			#print 'Yes!!'; #update_futakousin
			update_futakousin();
			param('mode') == 4 ? update_special_jyou_futakousin() : update_futuu();
		} elsif ( ($info->{$passthrough_id}{part} < param('part') || ($info->{$passthrough_id}{part} != param('part') && $info->{$passthrough_id}{josuu} != $josuu) && param('part') <= param('whole') && not (grep{$_ eq param('mode')} 4, 5) && (grep{$_ eq $info->{$passthrough_id}{sakujyoukyou}} '再', '没')) ||  ($info->{$passthrough_id}{sakujyoukyou} == '終' && param('mode') == 3)){
			#print 'Yes!!!'; #update_saikansyou
			update_saikansyou();
		} elsif (param('part') != param('whole') && grep{$_ eq param('mode')} 4, 5){
			#print 'Yes!!!!'; #update_special_jyou
			update_special_jyou();
		} elsif ($info->{$passthrough_id}{josuu} ne $josuu && $info->{$passthrough_id}{part} == param('part') && $info->{$passthrough_id}{whole} == $info->{$passthrough_id}{whole}){
			#print 'Yes!!!!!'; #update_josuu_all
			update_josuu_all();
		} elsif ($info->{$passthrough_id}{part} != $info->{$passthrough_id}{whole} && $info->{$passthrough_id}{josuu} eq $josuu && ($info->{$passthrough_id}{part} > param('part') || (grep{$_ eq param('mode')} 1, 2 && $info->{$passthrough_id}{part} >= param('part'))) && $info->{$passthrough_id}{whole} == $info->{$passthrough_id}{whole}){
			#print 'Yes!!!!!!'; #update_backtrace_part_error
			update_backtrace_part_error();
		} elsif ($info->{$passthrough_id}{sakuhajimari} != $hajimari) {
			update_hajimari();
		}
		#print 'Yes?';
	} else {
		#die 'No!';
		# Backtrace necessary for comparison to update sakuhin
		my $info_backtrace_query = "select reki.*, saku.hajimari, saku.josuu as `sakujosuu`, saku.yotei as `yotei`, saku.jyoukyou as `sakujyoukyou`, saku.whole as `sakuwhole`, saku.eternal as `eternal` from rireki reki left join sakuhin saku on reki.sid = saku.id where saku.`id` = ? order by jiten desc limit 1, 1";
		my $info_backtrace_syutoku = $dbh->prepare($info_backtrace_query);
		$info_backtrace_syutoku->execute(param('reference'));
		my $info_backtrace = $info_backtrace_syutoku->fetchall_hashref('sid');
		my $delete_query = "delete from rireki where id = ?";
		my $delete_query_jikkou = $dbh->prepare($delete_query);
		$delete_query_jikkou->execute($info->{$passthrough_id}{id});
		my $original_jyoukyou = defined $info_backtrace->{$passthrough_id}{id} && $info_backtrace->{$passthrough_id}{id} ? $info_backtrace->{$passthrough_id}{jyoukyou} : ''; #前に$info->{$passthrough_id}{sakujyoukyou}
		$original_jyoukyou = $info->{$passthrough_id}{sakujyoukyou} if $original_jyoukyou eq '葉' || $original_jyoukyou eq '飛';
		my $original_part = defined $info_backtrace->{$passthrough_id}{id} && $info_backtrace->{$passthrough_id}{id} ? $info_backtrace->{$passthrough_id}{part} : 0;
		my $original_whole = defined $info_backtrace->{$passthrough_id}{id} && $info_backtrace->{$passthrough_id}{id} ? $info_backtrace->{$passthrough_id}{whole} : $info->{$passthrough_id}{sakuwhole};
		my $original_owari = defined $info_backtrace->{$passthrough_id}{id} && $info_backtrace->{$passthrough_id}{id} ? $info_backtrace->{$passthrough_id}{jiten} : $info->{$passthrough_id}{sakuhajimari};
		my $original_yotei = defined $info_backtrace->{$passthrough_id}{id} && $info_backtrace->{$passthrough_id}{id} ? $info_backtrace->{$passthrough_id}{yotei} : 0;
		my $sakuhin_kousin_query = "update sakuhin set yotei = ?, jyoukyou = ?, part = ?, whole = ?, owari = ? where id = ?";
		my $sakuhin_kousin = $dbh->prepare($sakuhin_kousin_query);
		$sakuhin_kousin->execute($original_yotei, $original_jyoukyou, $original_part, $original_whole, $original_owari, param('reference'));
	}
}

my $query=new CGI;
print $query->redirect($ENV{HTTP_REFERER});
print "Content-type: text/html; charset=utf-8\n\n";