use HTML::Entities;
use LWP;
undef $/;
$prefix="http://web.archive.org/web/20051006225723/http://bbs.fuckedcompany.com/index.cgi?okay=get_topic&topic_id=";
open FH, "<bbs_topics.html"; # file pulled from following url that shows all the bbs.fc.com topics in wayback
                             # http://web.archive.org/web/*/http://bbs.fuckedcompany.com/index.cgi?okay=get_topic*
$content=<FH>;
close FH;
%unique_tids=();
@tids=$content=~/topic_id=0*([0-9]+)/sg;
foreach (@tids){
 $unique_tids{$_}=1;
}
#print scalar %unique_tids;exit;
#print join ("\n",  
@tids = sort { $a <=> $b } keys %unique_tids;
my $start_after=478516
my $ua = LWP::UserAgent->new(requests_redirectable=>[],keep_alive => 10);
foreach $tid (@tids) {
 next unless $tid>$start_after; #location header works better with get than head
 $commenturl=$prefix . $tid;
 #print $commenturl;exit;
 begin_topic_loop:
 my $resp=$ua->get($commenturl);
 my $code=$resp->code;
 if ($code==302) {
  my $redir = $resp->header("Location");
  print "got a 302 from $commenturl to $redir\n";
  if (!$redir) {die $resp->as_string;}
  next unless $redir;
  $commenturl="http://web.archive.org".$redir;
  print "trying $commenturl\n";
  goto begin_topic_loop;
 } elsif ($code==200) {
  #might still be a redir
  my $content=$resp->decoded_content;
  if ($content =~ /Redirecting to\.\.\./s) {
   print "got a javascript redir with $commenturl\n";
   my ($redir)=$content=~/document.location.href[^"]*"([^"]*)/;
   $redir=~s/\\//g;
   next unless $redir;
   $commenturl="http://web.archive.org".$redir;
   print "trying $commenturl\n";
   goto begin_topic_loop;
  }
  print "found comments for $commenturl with code $code\n";
   
  #save it off
  save($content, "topic_" . $tid .".html",$commenturl);
  #if this topic has >1 page...
  if (($pages)=$content=~/topic is ([0-9]+) pages long/s) {
   next unless $pages > 1;
   for ($page=1;$page<=$pages;$page++) {
    $commenturl=$prefix.$tid."&page=$page";
    begin_pages_loop:
    my $resp=$ua->get($commenturl);
    my $code=$resp->code;
    if ($code==302) {
     my $redir = $resp->header("Location");
     print "got a 302 from $commenturl to $redir\n";
     if (!$redir) {
	  die $resp->as_string;
	 }
     next unless $redir;
     $commenturl="http://web.archive.org".$redir;
     print "trying $commenturl\n";
     goto begin_pages_loop;
    } elsif ($code==200) {
     #might still be a redir
     my $content=$resp->decoded_content;
     if ($content =~ /Redirecting to\.\.\./s) {
      print "got a javascript redir with $commenturl\n";
      my ($redir)=$content=~/document.location.href[^"]*"([^"]*)/;
  	  $redir=~s/\\//g;
  	  next unless $redir;
      $commenturl="http://web.archive.org".$redir;
   	  print "trying $commenturl\n";
   	  goto begin_pages_loop;
     }
     print "found comments for $commenturl with code $code\n";
  	 $filename="topic_".$tid."_page_".$page.".html";
  	 save($content,$filename,$commenturl);
    } elsif ($code==404) {
  	 print "$commenturl not found\n";
    }
   }
  }
 }
}


sub save {
 my($content, $filename, $commenturl)=@_;
 return unless $filename;
 $convdir = "c:/fcscripts/bbstopics";
 if (-e $convdir . "/" . $filename ) {
  die $convdir . "/" . $filename . " exists!";
 }
 open FH, ">" , $convdir . "/" . $filename;
 if (defined $commenturl) {
  print FH "/*SAVED FROM $commenturl  */\n";
 }
 print FH $content;
 close FH;
}