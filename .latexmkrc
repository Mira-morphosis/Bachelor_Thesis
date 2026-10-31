use strict;
use warnings;
use utf8;
use JSON::PP;

# Tell LaTeX and BibTeX to search the template submodule for .sty, .cls, and .bst files
$ENV{'TEXINPUTS'} = './template//:' . ($ENV{'TEXINPUTS'} // '');
$ENV{'BSTINPUTS'} = './template//:' . ($ENV{'BSTINPUTS'} // '');

$pdf_mode = 1;          # produce PDF via pdflatex
$pdflatex = 'pdflatex -shell-escape -interaction=nonstopmode %O %S';

# Pre-compile hook: apply clear-text substitutions from substitutions.json to template files
if (-f 'substitutions.json') {
    open my $fh, '<:raw', 'substitutions.json' or die $!;
    my $json_bytes = do { local $/; <$fh> };
    close $fh;

    my $config = decode_json($json_bytes);
    while (my ($rel_path, $subs) = each %$config) {
        my $src = "template/$rel_path";
        next unless -f $src;

        open my $in, '<:encoding(UTF-8)', $src or die $!;
        my $content = do { local $/; <$in> };
        close $in;

        while (my ($search, $replace) = each %$subs) {
            $content =~ s/\Q$search\E/$replace/g;
        }

        my ($dir) = $rel_path =~ m{^(.*)/[^/]+$};
        mkdir $dir if $dir && !-d $dir;

        open my $out, '>:encoding(UTF-8)', $rel_path or die $!;
        print $out $content;
        close $out;
    }
}
