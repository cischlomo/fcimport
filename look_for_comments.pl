use DBI;
use LWP;
use Date::Parse;
use strict;
my $dbh=DBI->connect("dbi:ODBC:fc");
my $sth=0;

my $ua = LWP::UserAgent->new(requests_redirectable=>[]);

#my $html_newsid=94831;
#my $newsid=94831;
#my $wayback_prefix="http://web.archive.org/web/20021203085515/";
#get_comments($wayback_prefix,$newsid,$html_newsid);
#exit;

my @urls=qw#
/web/20021025140230/http://comments.fuckedcompany.com/fc/phparchives/index.php?startrow=21
#;

foreach my $url (@urls) {
 $url="http://web.archive.org".$url;
 print "---------- getting $url\n";
 #next;
 #my $url="http://web.archive.org/web/20011119184330/http://www.fuckedcompany.com/";
 my ($wayback_prefix)=$url=~/(^.*?\/)http/;
 my $req = HTTP::Request->new(GET=>$url);
 my $res = $ua->request($req);
 my $content=  $res->content;
 $res->code==200 or die "$url got " . $res->code;
 my @fucks=();
 if ($url=~/company\.com\/$/) {
  @fucks=$content=~/bullet[12].gif".*?>&nbsp;.*?<font size=1>[0-9]+ comments/isg;
 } else {
  @fucks=$content=~/(class="?bigheadline.*?br clear)/isg;
 }
 #print scalar @fucks; exit;
 foreach   (@fucks) {
 my ($headline,$company, $article,$when,$points,$html_newsid,$severity)=0;
 if ($url=~/company\.com\/$/) {
 ($headline,$article,$when,$company,$severity,$points,$html_newsid)=
  m#>\s*&nbsp;(.*?)</span>.*?article"?>(.*?)<br>\s*When: ([/0-9]+).*?Company: (.*?)<br>\s*[A-Z][a-z]+: ([0-9]+).*?Points: ([0-9]+).*?[^0-9]([0-9]{5,11})[^0-9]#s;
 } elsif ($url=~/php/) {
  ($headline,$article,$when,$company,$points,$html_newsid)=
   /bigheadline">(.*?)<\/span.*?\/b><br>\s*(.*?)<br>\s*When:\s*([\/a-zA-Z0-9: ]+?[AP]M).*?Company:\s*(.*?)<br.*?Points: ([0-9]+).*?newsid=([0-9]+)/s;
 } else {
   ($headline,$company, $article,$when,$points,$html_newsid)=
    /bigheadline">(.*?)<\/span.*?<b>(.*?)<\/b><br>\s*(.*?)<br>\s*When:\s*([\/0-9]+).*?Points:\s*([0-9]+).*?.*?<a href=.*?[^0-9]([0-9]{5,11})[^0-9]/s;
  }
  #print $headline , "\n";
  #print $article , "\n";
  #print $when , "\n";
  #print $company , "\n";
  #next;
  #print $points , "\n";
  #print $html_newsid , "\nxxxxxxxxxxxxx\n";
  #exit;
  next if $html_newsid==0;
  $headline=~s/'/''/sg;
  $article=~s#/web/[0-9]+/##g; #trims wayback urls from articles
  $article=~s/'/''/sg;
  $company=~s/\s*<a.*//si;
  $company=~s/'/''/sg;
  my $newsid=0;
  my $divisor=213213;
  if ( ($html_newsid % $divisor)==0 ) {
   $newsid=$html_newsid/$divisor
  } else {
   $newsid=$html_newsid;
  }
  
  
  #checking if already entered
  my $sql="select count(0) from tblnews where newsid=$newsid ";
  my $rows= $dbh->selectrow_array($sql);# or die "xxxx $sql";
  if ($rows>0) {
   print "$company already entered, checking if comments were entered\n";
   goto enter_comments;
  } else {
   print "$company not yet entered\n";
  }
  $sql="insert into tblnews (newsid, headline, description, description2, published, company, severity, points, deleted, approved) values ".
  "($newsid ,'$headline','$article', '$article',  convert( date, '$when' ), '$company', 100, $points, 0, 1)";
  #print $sql , "\n";next;
  $sth=$dbh->prepare($sql);
  $sth->execute;# or  die ($sql);
  $sql="insert into tblhtml (newsid) values ($newsid )";
  $sth=$dbh->prepare($sql);
  $sth->execute;
 
  enter_comments:
  #check if comments already entered
  $sql="select count(0) from tblcomments where newsid=$newsid";
  my $rows= $dbh->selectrow_array($sql);# or die "xxxx $sql";
  if ($rows>0) {
   print "comments for $newsid already entered\n";
   next;
  } else {
   print "comments for $newsid not yet entered\n";
   my $found_comments=0;
   if (!get_comments($wayback_prefix,$newsid,$html_newsid)) {
    my $sql="insert into tblcomments (commentid,newsid,username,subject,comment,posted) values ".
    "(0, $newsid , 'bot', 'not found','$newsid not in wayback',convert( date, '$when' ) )";
    $sth=$dbh->prepare($sql);
    $sth->execute or die $sql;
   }
  }
 }
 #exit;
}



sub get_comments {
 my ($wayback_prefix,$newsid, $html_newsid)=@_;
 my $num_pages=1;
 my $j=0;
 my $found_comments=0;
 while ($j<$num_pages) {
  $j++;
  my @commenturls=(
   "http://comments.fuckedcompany.com/phpcomments/index.php?newsid=$html_newsid&sid=1&page=$j&parentid=0&crapfilter=1",
   "http://comments.fuckedcompany.com/phpcomments/index.php?newsid=$html_newsid&page=$j&parentid=0&crapfilter=1",  
   "http://comments.fuckedcompany.com/phpcomments/index.php?newsid=$html_newsid&page=$j&parentid=0&crapfilter=0",
   "http://forum.fuckedcompany.com/phpcomments/index.php?newsid=$html_newsid&page=$j&parentid=0&crapfilter=1",
   "http://forum.fuckedcompany.com/phpcomments/index.php?newsid=$html_newsid&page=$j&parentid=0&crapfilter=0",
   "http://www.fuckedcompany.com/comments/html/$html_newsid-$j.html",
   "http://www.fuckedcompany.com/comments/index.cfm?newsID=$html_newsid".($j>1 ? "&page=$j" : "")
   );
  foreach my $commenturl (@commenturls) {
   $commenturl = $wayback_prefix . $commenturl;
   #print $commenturl;exit;
   beginloop:
   my $code=$ua->head($commenturl)->code;
   if ($code==302) {
    my $redir = $ua->head($commenturl)->header("Location");
    print "got a 302 with $commenturl\n";
	next unless $redir;
  	$commenturl="http://web.archive.org".$redir;
 	print "trying $commenturl\n";
 	goto beginloop;
   } elsif ($code==200) {
    #might still be a redir
    my $content=$ua->get($commenturl)->content;
    if ($content =~ /Redirecting to\.\.\./s) {
     print "got a fake 302 with $commenturl\n";
     my ($redir)=$content=~/document.location.href[^"]*"([^"]*)/;
	 $redir=~s/\\//g;
	 next unless $redir;
  	 $commenturl="http://web.archive.org".$redir;
 	 print "trying $commenturl\n";
	 #exit;
 	 goto beginloop;
	}
    print "found comments for $commenturl with code $code\n";
    if ($num_pages == 1 ) {
	 $found_comments=1;
     #$sth=$dbh->prepare("delete from tblcomments where newsid=$newsid ");
     #$sth->execute;
    }
	my $old_num_pages=$num_pages;
    ($num_pages)=$content=~/This topic is ([0-9]+) pages? long.*?<\/td/is;
	if ($old_num_pages>$num_pages) {
	 $num_pages=$old_num_pages;
	}
    print "num_pages: $num_pages\n";
	my (@pids , @dates , @messages, @subjects, @authors) = ();
	if ($commenturl=~/comments\.fuckedcompany/) {
     @dates = $content =~ /<font[^>]*>([a-zA-Z0-9: ]+?[A-Z]{3})/sg; #starting around sept 2002
	 #print join "\n", @dates; exit;
     @messages = $content =~ /<\/table>\s*<span class=regular>(.*?)<\/span>\s*<br>\s*<table/isg;
     @subjects = $content=~/<span\s+class="?formlabel"?>(.*?)<\/span>/isg;
     @authors = $content=~/td class=regular bgcolor=[A-F0-9]{6} valign=top><b>(.*?)<\/b/isg;	
	} elsif ($commenturl=~/php/ ) {
     @dates = $content =~ /<font[^>]*>([\/a-zA-Z0-9: ]+?[AP]M [A-Z]{3})/sg;
     @messages = $content =~ /<\/table>\s*<span class=regular>(.*?)<\/span>\s*<br>\s*<table/isg;
     @subjects = $content=~/<span\s+class="?formlabel"?>(.*?)<\/span>/isg;
     @authors = $content=~/td class=regular bgcolor=[A-F0-9]{6} valign=top><b>(.*?)<\/b/isg;	
	} else {
     @pids = $content =~ /regular><!-- ([0-9]+)/sg;
     @dates = $content =~ /<font[^>]*>([0-9]+\/[0-9]+\/[0-9]+ [0-9][0-9]:[0-9][0-9] [AP]M [A-Z]{3})/sg;
     @messages = $content =~ /regular><!-- [0-9]+ -->(.*?)<\/span/isg;
     @subjects=$content=~/<span\s+class="?formlabel"?>(.*?)<\/span>/isg;
     @authors=$content=~/td class=regular bgcolor=6C000E valign=top><b>(.*?)<\/b/isg;
	}
    if (@messages == @subjects && @messages == @dates && @messages == @authors) {
	 if (scalar @messages==0 ) {
	  if ($j==1) { #still on first page
	   $found_comments=0;
	   print "no comments found for $commenturl\n";
	  }
	  next;
	 }
     print "consistency check passed\n";
	 #print join "\n",@subjects;exit;
     my $i=0;
     foreach (@messages) {
	  my $sql=undef;
	  #print scalar @pids;exit;
	  if (scalar @pids > 0) {
	   $sql="insert into tblcomments (commentid,newsid,username,subject,comment,posted) values ($pids[$i],$newsid ,'" .   
       $authors[$i]=~s/'/''/gr . "','" . $subjects[$i]=~s/'/''/gr . "','";
	  } else {
	   $sql="insert into tblcomments (commentid,newsid,username,subject,comment,posted) values (999,$newsid ,'" .   
       $authors[$i]=~s/'/''/gr . "','" . $subjects[$i]=~s/'/''/gr . "','";
	  }
      my ($message)=/(.*)/sg;
      $sql.=$message=~s/'/''/gr;
      my @time = gmtime (str2time ($dates[$i]));
      $sql.="'," . sprintf ("{ts'%04d-%02d-%02d %02d:%02d:%02d'}",$time[5]+1900,$time[4]+1,$time[3],$time[2],$time[1],$time[0]) . ")";
      $i++;
      $sth=$dbh->prepare($sql);
      $sth->execute or die ($sql);
     }
    } else {
     print "consistency failed with url $commenturl\n";
     print "pids: " , scalar @pids , "\n";
     print "messages: ", scalar @messages , "\n";
     print "subjects: " , scalar @subjects , "\n";
     print "dates: " , scalar @dates , "\n";
     print "authors: " , scalar @authors , "\n";
	 exit;
    }
    last; #found a good url, no need to try others
   } else {
    print "error $code for $commenturl\n";
   }
  }
 }
 return $found_comments;
}
