use Date::Parse;
use HTML::Entities;
use DBI;

use warnings; use strict;

my $host="xbmc";
my $user="ff";
my $password="ff";
my $debug=0;
my $dsn="dbi:mysql:host=$host;database=campidiot"; 
my $sql="";
my $filename="";
my $dbh=0;

sub handle_error {
 my $error=shift;
 if ($error=~/syntax/) {
  die $error .", " . $sql . " " . $File::Find::dir . "/" . $filename ;
 }
}

sub sqlstuff {
 return if $debug;
 ($sql)=@_;
 if  ($debug) {
  print "$sql\n";
  return;
 }
 my $sth=$dbh->prepare($sql);
 $sth->execute ;
}

sub topic_exists {
 return 0 if $debug;
 my ($pid)=@_;
 my $sql = "select count(0) from topics where id=$pid";
 return $dbh->selectrow_array($sql);
}

undef $/;

my $arg=$ARGV[0];
my $only_do_topic=0;
my $start_at_topic=0;
if (@ARGV) {
 if ($arg=~/[a-zA-Z]/) {
  #die "starting";
  $debug=1;
  open FH, "<" , $arg or die "couldn't open file";
  my $content=<FH>;
  close FH;
  parse_posts($content);
  exit;
 } elsif ($arg=~/^[0-9]+$/) {
  $only_do_topic=$arg;
 }
}

$dbh=DBI->connect($dsn,$user,$password, 
 {PrintError  => 0, HandleError => \&handle_error}
);

if ($only_do_topic) {
 $sql="delete from ci_posts where topic_id=$arg";
 sqlstuff($sql);
}

use File::Find;
find (\&wanted,qw/bbstopics/);

sub wanted {
 return unless /topic_/;
 return unless $only_do_topic==0 || /$only_do_topic/;
 my ($topicnum)=/topic_([0-9]+)/;
 return unless $topicnum>0; #401175
 $filename=$_;
 open FH,"<", $filename ;
 my $content=<FH>;
 close FH;
 parse_posts($content);
}

sub dbesc{
 my $string=shift;
 $string=~s/'/''/g;
 $string=~s/\\/\\\\/g;
 $string;
}

sub parse_posts {
#die "oops";
 my ($content)=@_;
 my ($tid,$topic)=$content=~m#topic_id=([0-9]+).*?<title>(.*?)</title>#s;
 return if !$topic;
 if(!topic_exists($tid)) {
  #only insert a topic if it hasn't been done yet. Still need to insert posts otherwise
  $topic=decode_entities($topic);
  $sql="insert into ci_topics (id,subject) values ($tid, '" . dbesc($topic) . "')";
  sqlstuff($sql);
 }
 $content=~s/.*?head -->//s;
 $content=~s#</table>\s*<br>\s*This topic.*##s;
 $content=~s#<A NAME=[0-9]*>(.*?)</A>#$1#sg;
 my @posts=$content=~m#<td valign=top><b>.*?</b>.*?Delete.*?</table>#sg;
 
 
 my $numposts=0;
 foreach $topic ( @posts ) {
  $numposts++;
  my ($author,$title,$posted,$message) = $topic =~ 
   m#<td valign=top><b>(.*?)</b>.*?<font size=1>(.*?)</font>.*?<font size=1>(.*?)</font>.*?</table>(.*?)<br>\s*<table#s;
 
  if (my($userid,$author1)=$author=~m#user_id=([0-9]+)">(.*?)</a#s) { #s also removes embedded crs
   #print "u: $userid\n";
   $author=$author1;
  }
  $author=~s#<u> </u>#_#g;
  if ($debug) {
   #print "a: $author\n";
   #next;
   #print "t: $title\n";
   #print "p: $pid\n";
   #print "p: $posted\n";
   #print "m: $message\n*******\n";
  }
  $posted=str2time($posted);
  debbsify(\$message);
  $sql="insert into ci_posts (posted,poster,message,topic_id) values ($posted,'".dbesc($author)."','".dbesc($message)."',$tid)";
  if ($debug) {
   print $message;
  } else {
   sqlstuff($sql);
  }
 }
}

sub debbsify {
 my ($content)=@_;
 $$content=decode_entities($$content);
 $$content=~s#/web/[0-9]+/##sg; #trims wayback urls
 if ($$content=~s#<A[^>]+>(?=<A)##sg) {
  $$content=~s#</A>\s*</A>#</A>#isg;
 }
 my $recurslimit=10; 
 while ($$content=~m#TARGET=_blank# && $recurslimit-- > 0) {
  if ($$content=~m#<A.*?HREF="([^"]*)"\s*TARGET=_blank>(.*?)</A>#is) {
   if ($1 eq $2) {
    $$content=~s#<A.*?HREF="([^"]*)"\s*TARGET=_blank>(.*?)</A>#$1#is;
   } else {
    $$content=~s#<A.*?HREF="([^"]*)"\s*TARGET=_blank>(.*?)</A>#\[url=$1\]$2\[/url\]#is;
   }
  }
 }
 $recurslimit=10;
 while ($$content=~m#</?BLOCKQUOTE>#is && $recurslimit-- > 0) {
  $$content=~s#<BLOCKQUOTE><font size="1">quote:</font><HR>Originally posted by\s*(.*?)<br>(.*?)<HR></BLOCKQUOTE>#[quote="$1"]$2\[/quote]#is
    ||
  $$content=~s#<BLOCKQUOTE><font size="1">quote:</font><HR>(.*?)<HR></BLOCKQUOTE>#[quote]$1\[/quote]#is
    ||
  $$content=~s#<BLOCKQUOTE><font size="1">quote:</font><HR>(.*)#[quote]$1\[/quote]#is
    ||
  $$content=~s#<HR></BLOCKQUOTE>##is
  ;
  #if ($recurslimit==3) {
   #print "\nxxxxxxxxxxxxxxxxxx\n" , $$content , "\nxxxxxxxxxxxxxxxxxx\n";exit;
  #}
 }
 $$content=~s#<B>(.*?)</B>#\[b\]$1\[/b\]#sg;
 $$content=~s#<I>(.*?)</I>#\[i\]$1\[/i\]#sg;
 $$content=~s#<IMG SRC.*?TITLE="([^"]*)">#:$1:#sg;
 $$content=~s#<IMG SRC.*?ALT="([^"]*)">#:$1:#sg;
 $$content=~s#<IMG SRC.*?icons/([^\.]*).gif">#:$1:#sg;
 $$content=~s#To see the rest of this post.*?</a>.*?missing.*?[0-9]+\s+##s;
 $$content=~s/<br>/\r\n/sg;
}
