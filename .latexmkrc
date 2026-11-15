use strict;
use warnings;
use utf8;
use JSON::PP;
use File::Path qw(make_path remove_tree);
use File::Temp qw(tempdir);
use File::Copy qw(cp);
use Cwd;

my $original_dir = getcwd();
print STDERR "Working directory at start: $original_dir\n";
my $keep_temp = $ENV{'KEEP_TEMP'} // 0;

# Create a secure temporary directory in /tmp with a completely random name
my $temp_base = tempdir(DIR => '/tmp', CLEANUP => 0);
mkdir $temp_base, 0700;
my $temp_covermatter = "$temp_base/covermatter";
mkdir $temp_covermatter, 0700;

print STDERR "Temp directory: $temp_base\n" if $keep_temp;

# Generate covermatter files from substitutions.json
if (-f 'substitutions.json') {
    open my $fh, '<:raw', 'substitutions.json' or die $!;
    my $json_bytes = do { local $/; <$fh> };
    close $fh;

    my $config = decode_json($json_bytes);
    while (my ($rel_path, $subs) = each %$config) {
        my $dest_path = $temp_covermatter . substr($rel_path, index($rel_path, '/'));
        
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
        open my $out, '>:encoding(UTF-8)', $dest_path or die $!;
        print $out $content;
        close $out;
    }
}

# Copy covermatter/figure if exists locally
if (-d "$original_dir/covermatter/figure") {
    my $dir_handle;
    opendir $dir_handle, "$original_dir/covermatter/figure" or warn "Cannot open covermatter/figure: $!";
    if ($dir_handle) {
        while (my $file = readdir($dir_handle)) {
            next if $file =~ /^\./;
            mkdir "$temp_covermatter/figure" unless -d "$temp_covermatter/figure";
            cp("$original_dir/covermatter/figure/$file", "$temp_covermatter/figure/$file") or warn "Failed to copy: $!";
        }
        closedir $dir_handle;
    }
}

# Copy template/covermatter/figure if exists
if (-d "$original_dir/template/covermatter/figure") {
    my $dir_handle;
    opendir $dir_handle, "$original_dir/template/covermatter/figure" or warn "Cannot open template/covermatter/figure: $!";
    if ($dir_handle) {
        while (my $file = readdir($dir_handle)) {
            next if $file =~ /^\./;
            mkdir "$temp_covermatter/figure" unless -d "$temp_covermatter/figure";
            cp("$original_dir/template/covermatter/figure/$file", "$temp_covermatter/figure/$file") or warn "Failed to copy: $!";
        }
        closedir $dir_handle;
    }
}

# Copy all necessary files to temp directory
# Use absolute path for main.tex
use File::Spec;
my $main_tex_abs = File::Spec->rel2abs("main.tex", $original_dir);
print STDERR "Copying from: $main_tex_abs\n";
open(my $test_fh, '<', $main_tex_abs) or die "Cannot open $main_tex_abs: $!";
my $first_line = <$test_fh>;
close $test_fh;
print STDERR "First line of source: $first_line\n";
cp($main_tex_abs, "$temp_base/main.tex") or die "Cannot copy main.tex from $main_tex_abs: $!";

# Copy capitoli directory
my $dir_handle;
opendir $dir_handle, "$original_dir/capitoli" or die "Cannot open capitoli: $!";
while (my $file = readdir($dir_handle)) {
    next if $file =~ /^\.|^esempio/;
    mkdir "$temp_base/capitoli" unless -d "$temp_base/capitoli";
    cp("$original_dir/capitoli/$file", "$temp_base/capitoli/$file") or warn "Failed to copy capitoli/$file: $!";
}
closedir $dir_handle;

# Copy figure directory
if (-d "$original_dir/figure") {
    opendir $dir_handle, "$original_dir/figure" or die "Cannot open figure: $!";
    while (my $file = readdir($dir_handle)) {
        next if $file =~ /^\./;
        mkdir "$temp_base/figure" unless -d "$temp_base/figure";
        cp("$original_dir/figure/$file", "$temp_base/figure/$file") or warn "Failed to copy figure/$file: $!";
    }
    closedir $dir_handle;
}

# Copy references.bib
cp("$original_dir/references.bib", "$temp_base/references.bib") or die "Cannot copy references.bib: $!";

# Copy template directory
opendir $dir_handle, "$original_dir/template" or die "Cannot open template: $!";
while (my $file = readdir($dir_handle)) {
    next if $file =~ /^\./ || $file eq 'covermatter' || $file eq 'main.tex' || $file eq 'capitoli' || $file eq 'figure' || $file eq 'references.bib';
    my $src = "$original_dir/template/$file";
    my $dst = "$temp_base/$file";
    if (-d $src) {
        File::Path::make_path($dst);
        opendir my $subdir, $src or next;
        while (my $subfile = readdir($subdir)) {
            next if $subfile =~ /^\./;
            my $subsrc = "$src/$subfile";
            my $subdst = "$dst/$subfile";
            if (-d $subsrc) {
                File::Path::make_path($subdst);
            } else {
                cp($subsrc, $subdst) or warn "Failed to copy template/$file/$subfile: $!";
            }
        }
        closedir $subdir;
    } else {
        cp($src, $dst) or warn "Failed to copy template/$file: $!";
    }
}
closedir $dir_handle;

# Modify main.tex in temp directory: replace __COVERMATTER__ with absolute path
open my $in, '<:encoding(UTF-8)', "$temp_base/main.tex" or die "Cannot read temp main.tex: $!";
my $main_content = do { local $/; <$in> };
close $in;

# Replace __COVERMATTER__ with relative path
$main_content =~ s/__COVERMATTER__\//covermatter\//g;

# Write back modified main.tex
open my $out, '>:encoding(UTF-8)', "$temp_base/main.tex" or die "Cannot write temp main.tex: $!";
print $out $main_content;
close $out;

# Set environment to find everything
$ENV{'TEXINPUTS'} = "$temp_base/:" . ($ENV{'TEXINPUTS'} // '');
$ENV{'BIBINPUTS'} = "$temp_base/:" . ($ENV{'BIBINPUTS'} // '');
$ENV{'BSTINPUTS'} = "$temp_base/:" . ($ENV{'BSTINPUTS'} // '');

# Change to temp directory and run pdflatex
chdir $temp_base or die "Cannot chdir to $temp_base: $!";

my $pdf_mode = 1;
my $pdflatex = 'pdflatex -shell-escape -interaction=nonstopmode %O %S';

# Tell latexmk to use our modified file
my $rcs_file = "$temp_base/main.tex";
my @source_files = ("$temp_base/main.tex");

# Set the output directory
my $out_dir = $temp_base;

# Register cleanup and PDF copy in END block
END {
    chdir $original_dir;
    my $src_pdf = "$temp_base/main.pdf";
    my $dst_pdf = "main.pdf";
    if (-f $src_pdf) {
        cp($src_pdf, $dst_pdf) or warn "Failed to copy PDF: $!";
    }
    remove_tree($temp_base, {verbose => 0}) if ($temp_base && -d $temp_base && !$keep_temp);
    remove_tree('covermatter', {verbose => 0}) if -d 'covermatter';
    print STDERR "Keeping temp dir: $temp_base\n" if $keep_temp;
}

# Also cleanup on interrupt
$SIG{INT} = sub {
    chdir $original_dir;
    remove_tree($temp_base, {verbose => 0}) if ($temp_base && -d $temp_base && !$keep_temp);
    remove_tree('covermatter', {verbose => 0}) if -d 'covermatter';
    exit 1;
};
$SIG{TERM} = sub {
    chdir $original_dir;
    remove_tree($temp_base, {verbose => 0}) if ($temp_base && -d $temp_base && !$keep_temp);
    remove_tree('covermatter', {verbose => 0}) if -d 'covermatter';
    exit 1;
};
