use File::Find;
use Date::Parse;
use HTML::Entities;
use DBI;

my $host="xbmc";
my $user="ff",$password="ff";
my $dsn="dbi:mysql:host=$host;database=campidiot"; 
my $dbh=0;
#my $debug=1;

$dbh=DBI->connect($dsn,$user,$password, 
 {PrintError  => 0, HandleError => \&handle_error}
) or die "oops";
find (\&wanted,qw#f6#);

sub wanted {
 next unless /[0-9]+\.html/;
 $file=$_;
 ($fileno)=/([0-9]+)/;
 undef $/;
 open FILE, '<:encoding(utf8)' , $file;
 $str=<FILE>;
 $str=~s#</?font[^>]*>##isg;
 $str=~s#FCArchive/images/##isg;
 $str=~/<table[^>]*>(.*)<\/table>/is;
 $postbody=$1;
 @tables=$postbody=~/(<table[^>]*>.*?<\/table>)/isg;
 
 @tr=$tables[2]=~/(<tr[^>]*>.*?<\/tr>)/isg;
 @td=$tr[0]=~/(<td[^>]*>.*?<\/td>)/isg;
 ($topic)=$tr[0]=~/Topic.*;\s*(.*)<\/b>/isg;
 
 @td=();
 $postno=0;
 @posts=();
 for (1..@tr-1) {
  @td=$tr[$_]=~/(<td[^>]*>.*?<\/td>)/isg;
  ($author)=$td[0]=~/<b>(.*)<\/b><br>(\S+)/i;
  $postdata=[];
  push @$postdata, sprintf ("%06d",$postno++);
  $reg=$2;
  push @$postdata, $author;
  $td[1]=~/posted\s*([0-9]+)-([0-9]+)-([0-9]+)\s*([0-9][0-9]):([0-9][0-9]):([0-9][0-9])/i;
  $posted_date="$2-$3-$1";
  push @$postdata, $posted_date;
  #convert to am/pm from 24hr
  my $hr=$4;
  my $apm="";
  if ($hr==0) {
   $hr=12;
   $apm="PM"
  } elsif ($hr<12) {
   $apm="AM";
  } elsif ($hr>12) {
   $hr-=12;
   $apm="PM";
  }
  $posted_time=sprintf("%02d:%02d %s",$hr,$5,$apm);
  push @$postdata, $posted_time;
  ($message)=$td[1]=~/<hr>(.*)<p align="?right/i;
 
  push @$postdata, $message;
  
  push @$postdata, $reg;
  
  push @posts,$postdata;
 }
 
 my $tz = " -0400";
 $first_post=$posts[0];
 $posted=$first_post->[2] . " " . $first_post->[3] . $tz;
 $posted=str2time ($posted);
 #$tid=$fileno;
 $sql="insert into ci_topics (id, poster, subject,posted,forum_id) values (0, '" . 
  dbesc($first_post->[1]) . "', '" . dbesc($topic) . "', $posted, 17)";

 $tid=sqlstuff($sql);
 
 $posted="";
 foreach (@posts) {
  $posted=$_->[2] . " " . $_->[3] . $tz;
  $posted=str2time ($posted);
  $poster=dbesc($_->[1]);
  $message= dbesc($_->[4]) ;
  debbsify(\$message);
  $sql="insert into ci_posts (id,poster,posted,message,topic_id) values (0, '$poster',$posted, '$message',$tid)";
  sqlstuff($sql);
 } 
}

sub dbesc{
 my $string=shift;
 $string=~s/'/''/g;
 $string=~s/\\/\\\\/g;
 $string;
}
sub debbsify {
 my ($content)=@_;
 my $recurslimit=10; 
 while ($$content=~m#<BLOCKQUOTE>code:#is && $recurslimit-- > 0) {
  $$content=~s#<BLOCKQUOTE>code:<HR><pre>(.*?)</pre><HR></BLOCKQUOTE>#[code]$1\[/code]#is;
  #print $$content;
 }
 $$content=decode_entities($$content);
 if ($$content=~s#<A[^>]+>(?=<A)##sg) {
  $$content=~s#</A>\s*</A>#</A>#isg;
 }
 $recurslimit=10; 
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
  $$content=~s#<BLOCKQUOTE><font size="1"[^>]+>quote:</font><HR>Originally posted by\s*(.*?):<br><b>(.*?)</b><HR></BLOCKQUOTE>#[quote="$1"]$2\[/quote]#is
    ||
  $$content=~s#<BLOCKQUOTE>quote:<HR>Originally posted by\s*(.*?):<br><b>(.*?)</b><HR></BLOCKQUOTE>#[quote="$1"]$2\[/quote]#is
    ||	
  $$content=~s#<BLOCKQUOTE><font size="1"[^>]+>quote:</font><HR>(.*?)<HR></BLOCKQUOTE>#[quote]$1\[/quote]#is
    ||
  $$content=~s#<BLOCKQUOTE><font size="1"[^>]+>quote:</font><HR>(.*)#[quote]$1\[/quote]#is
    ||
  $$content=~s#<HR></BLOCKQUOTE>##is
  ;
 }
 $$content=~s#<B>(.*?)</B>#\[b\]$1\[/b\]#sg;
 $$content=~s#<I>(.*?)</I>#\[i\]$1\[/i\]#sg;
 $$content=~s#<IMG SRC.*?ubb/([^\.]*).gif">#:$1:#sg;
 $$content=~s/<br>/\r\n/isg;
 $$content=~s/<p>/\r\n\r\n/isg;
}
sub sqlstuff {
 ($sql)=@_;
 if  ($debug) {
  print "$sql\n";
  return;
 }
 my $sth=$dbh->prepare($sql);
 $sth->execute ;
 $sth->{'mysql_insertid'};
}

sub handle_error {
 my $error=shift;
 if ($error=~/syntax/) {
  die $error .", " . $sql . " " . $File::Find::dir . "/" . $filename ;
 }
}

