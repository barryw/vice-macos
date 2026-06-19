#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

perl -MJSON::PP - "$ROOT_DIR" <<'PERL'
use strict;
use warnings;
use JSON::PP qw(decode_json);

my ($root_dir) = @ARGV;
my $failed = 0;

sub slurp {
    my ($path) = @_;
    open my $handle, '<:encoding(UTF-8)', $path or die "Unable to read $path: $!\n";
    local $/;
    return <$handle>;
}

sub slurp_bytes {
    my ($path) = @_;
    open my $handle, '<:raw', $path or die "Unable to read $path: $!\n";
    local $/;
    return <$handle>;
}

sub fail {
    my ($message) = @_;
    print STDERR "$message\n";
    $failed = 1;
}

sub swift_code_listings {
    my ($value) = @_;

    if (ref($value) eq 'HASH') {
        my @listings;
        if (($value->{type} // '') eq 'codeListing' &&
            ($value->{syntax} // '') eq 'swift' &&
            ref($value->{code}) eq 'ARRAY') {
            push @listings, join("\n", @{$value->{code}});
        }

        for my $child (values %{$value}) {
            push @listings, swift_code_listings($child);
        }

        return @listings;
    }

    if (ref($value) eq 'ARRAY') {
        my @listings;
        for my $child (@{$value}) {
            push @listings, swift_code_listings($child);
        }
        return @listings;
    }

    return ();
}

my $example_path = "$root_dir/MacVICEKit/Tests/MacVICEKitTests/DocumentationQuickStartExample.swift";
my $example_source = slurp($example_path);
my ($snippet) = $example_source =~ m{// BEGIN: MacVICEKitQuickStart\s*\n(.*?)\n// END: MacVICEKitQuickStart}s;
die "MacVICEKit quick-start snippet markers were not found in $example_path\n" unless defined $snippet;
$snippet =~ s/\A\s+|\s+\z//g;

for my $path (
    "$root_dir/MacVICEKit/README.md",
    "$root_dir/MacVICEKit/Sources/MacVICEKit/MacVICEKit.docc/MacVICEKit.md",
) {
    my $contents = slurp($path);
    fail("$path does not contain the compiled MacVICEKit quick-start example.")
        if index($contents, $snippet) < 0;
}

my $website_page = "$root_dir/website/macvicekit.html";
if (-f $website_page) {
    my $contents = slurp($website_page);
    fail("$website_page does not contain the compiled MacVICEKit quick-start example.")
        if index($contents, $snippet) < 0;
}

my $generated_docc = "$root_dir/website/docs/macvicekit/data/documentation/macvicekit.json";
if (-f $generated_docc) {
    my $json = decode_json(slurp_bytes($generated_docc));
    my @listings = swift_code_listings($json);
    my $found = grep { $_ eq $snippet } @listings;
    fail("$generated_docc does not contain the compiled MacVICEKit quick-start example. Run website/tools/build-macvicekit-docs.sh.")
        unless $found;
}

exit($failed ? 1 : 0);
PERL
