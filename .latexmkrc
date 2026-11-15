use strict;
use warnings;
use utf8;
use JSON::PP;
use File::Path qw(make_path remove_tree);
use File::Temp qw(tempdir);

# Create a secure temporary directory in /tmp with a completely random name
my $temp_base = tempdir(DIR => '/tmp', CLEANUP => 0);
mkdir "$temp_base", 0700;  # Ensure it's only accessible by owner
my $temp_covermatter = "$temp_base/covermatter";
mkdir $temp_covermatter, 0700;

# Create symlink so \include{covermatter/...} works but files are in /tmp
if (!-l 'covermatter') {
    remove_tree('covermatter', {verbose => 0}) if -d 'covermatter';
    symlink $temp_covermatter, 'covermatter' or die "Cannot create symlink: $!";
}

# Tell LaTeX to search template/ for .sty/.cls files
$ENV{'TEXINPUTS'} = "./$temp_base//:./template//:" . ($ENV{'TEXINPUTS'} // '');
$ENV{'BSTINPUTS'} = './template//:' . ($ENV{'BSTINPUTS'} // '');

$pdf_mode = 1;
$pdflatex = 'pdflatex -shell-escape -interaction=nonstopmode -aux-directory=' . $temp_base . ' %O %S';

if (-f 'substitutions.json') {
    open my $fh, '<:raw', 'substitutions.json' or die $!;
    my $json_bytes = do { local $/; <$fh> };
    close $fh;

    my $config = decode_json($json_bytes);
    while (my ($rel_path, $subs) = each %$config) {
        my $dest_path = "$temp_covermatter/$rel_path";
        
        if ($rel_path eq 'covermatter/dedica.tex') {
            my $quote = $subs->{quote} // '';
            my $author = $subs->{author} // '';
            my $content = "\\begin{titlepage}\n";
            $content .= "\\nonumber\n";
            $content .= "\\null \\vspace{\\stretch{1}}\n";
            $content .= "\\begin{flushright}\n";
            $content .= "\\begin{verse}\n";
            $content .= "\\textit{$quote}\n";
            $content .= "\\end{verse}\n";
            $content .= "-- \\textit{$author}\n";
            $content .= "\\end{flushright}\n";
            $content .= "\\end{titlepage}\n";
            my ($dir) = $dest_path =~ m{^(.*)/[^/]+$};
            make_path($dir) if $dir;
            open my $out, '>:encoding(UTF-8)', $dest_path or die $!;
            print $out $content;
            close $out;
            next;
        }
        if ($rel_path eq 'covermatter/ringraziamenti.tex') {
            my $text = $subs->{"Ringraziamenti qui..."} // '';
            my $content = "\\chapter*{Acknowledgements}\n";
            $content .= "\\pagenumbering{gobble}\n";
            $content .= "\\fancyhf{}\n";
            $content .= "\n";
            $content .= "$text\n";
            my ($dir) = $dest_path =~ m{^(.*)/[^/]+$};
            make_path($dir) if $dir;
            open my $out, '>:encoding(UTF-8)', $dest_path or die $!;
            print $out $content;
            close $out;
            next;
        }
        my $src = "template/$rel_path";
        next unless -f $src;
        open my $in, '<:encoding(UTF-8)', $src or die $!;
        my $content = do { local $/; <$in> };
        close $in;
        while (my ($search, $replace) = each %$subs) {
            $content =~ s/\Q$search\E/$replace/g;
        }
        my ($dir) = $dest_path =~ m{^(.*)/[^/]+$};
        make_path($dir) if $dir;
        open my $out, '>:encoding(UTF-8)', $dest_path or die $!;
        print $out $content;
        close $out;
    }
}

# Cleanup: remove symlink and temp directory
END {
    unlink 'covermatter' if -l 'covermatter';
    remove_tree($temp_base, {verbose => 0}) if $temp_base && -d $temp_base;
}
