#!/usr/bin/env perl
use strict; use warnings;
use LWP::UserAgent;
use Getopt::ArgParse;
use Getopt::Long;
use URI::URL;
use HTTP::Cookies::Netscape;
use ShemPerl::Logging qw('error' 'success');

my $ua = LWP::UserAgent->new;
my $ap = Getopt::ArgParse->new_parser(
    prog => 'HTTP Fetcher',
    description => 'Perl script to fetch HTTP resources and store it locally for analysis.',
);

$ap->add_arg("--method", '-m', help=>'Method to use (GET || POST)', required => 1);
$ap->add_arg("--target", "-t", help=>'URL resource to fetch data from.', required => 1);
$ap->add_arg("--data", "-d", help=>'Data parameters separated by comma to include inside request. Ex: password:pass,user:root', required => 0, type => 'Array', split=>',');
$ap->add_arg('--cookies', '-c', help=>'File containing cookies to be loaded.', required=> 0);
my $args = $ap->parse_args( @ARGV );

# Global Variables
my $out_file = "" ;
my $out_folder = "" ;

sub check_args
{
    ShemPerl::Logging::info;
	print "Validating arguments ...\n";

	if ( ($args->method ne "GET") && ($args->method ne "POST" )) {
		ShemPerl::Logging::error;
        print "Invalid method.\n";
		return 1;
	}

	ShemPerl::Logging::success;
    print "Arguments validated.\n\n";
	return 0;
}

sub dissecate_url
{
	my $url = URI::URL->new($args->target);

    $out_file = $url->path;
    $_ = $out_file;
	tr /\///d;  # Removes the "/" from path variable.
	$out_file = $_;

    # If path is '/', i need to set a default name.
    if ( $out_file eq "" ) {
        $out_file = "index.html";
    }

    # Define the output folder name
    $out_folder = $url->netloc;

    ShemPerl::Logging::info;
    print "Output folder set to  ...: ", $out_folder . "\n";

    ShemPerl::Logging::info;
	print "Output file set to ......: ", $out_file . "\n\n";
	return 0;
}

sub do_work
{
	# Send the request and store the result into out file.
	# =======================================================
    ShemPerl::Logging::info;
    my $method = $args->method;
    my %payload;
    my $cookies;
    print "Sending $method request to ", $args->target . " ...\n";
	my $req = HTTP::Request->new($args->method, $args->target);

    if ( $args->cookies && -f $args->cookies ) {
        ShemPerl::Logging::info;
        print "Loading cookies from file ...\n";

        my $cookie_jar = HTTP::Cookies::Netscape->new(
            File => $args->cookies,
        );

        $ua->cookie_jar($cookie_jar);
        ShemPerl::Logging::success;
        print "Cookies loaded.\n";
    } else {
        ShemPerl::Logging::error;
        print "Error loading cookies from file.\n";
        exit 1;
    }

    if ( $method eq "GET" && $args->data ) {
        ShemPerl::Logging::warn;
        print "Ignoring --data because method $method does not allow payload.\n";
    }

    if ( $method eq "POST" && $args->data ) {
        # set-up the request payload
        foreach ( $args->data ) {
            my ($k, $v) = split(/:/, $_);
            $payload{$k} = $v;
        }

        ShemPerl::Logging::info;
        $req->content(%payload);
        print "Payload data embedded to request.\n";
    }
    #$req->content( $args-> $data );

	my $resp = $ua->request($req);
    # Check if it was successfull
    if ( $resp->is_success ) {
        ShemPerl::Logging::success;
        print "Request sent.\n\n";
    } else {
        ShemPerl::Logging::error;
        print "Request has not been sent.\n\n";
        print "HTTP error code: ", $resp->code . "\n";
        print "HTTP error mesg: ", $resp->message . "\n";
        exit 1;
    }

    # Store response content to file.
    if ( ! -d $out_folder ) {
        mkdir $out_folder;
    }

    chdir $out_folder;

	open my $fp, '>', $out_file or die "Could not open file.\n";
    print { $fp } $resp->content or die "Could not write to file.\n";

    ShemPerl::Logging::success;
    print "Response content written to file '$out_file'.\n";

    close $fp;
}

sub main
{
	check_args;
	dissecate_url;
    do_work;
    return 0;
}

main;
