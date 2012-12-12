#!/usr/bin/perl 
use CGI;
my $cgi = CGI->new;
my $name = $cgi->param('name') || $ARGV[0] || 'ALERT-SENHA-A-4-1-5-GUICHE-S-0.mp3';
$name =~ s/\.mp3$//g;
my @names = (split /-/, $name); 
print $cgi->header( -type => 'audio/mp3' );
foreach my $n (@names) {
	open (my $fh, '<', '/usr/share/fila/Fila-Web/root/static/audio/'.$n.'.mp3');
	binmode($fh);
	my $data;
	while ((my $n = read ($fh, $data, 1024)) != 0) {
		print $data;
	}
}
