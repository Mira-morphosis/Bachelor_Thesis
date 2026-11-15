# ---------------------------------------------------------------------------
# .latexmkrc — build configuration for the thesis.
#
# latexmk -pvc best practices (LaTeX Workshop integration):
#   * Compile IN PLACE, in the project root (no chdir, no $out_dir). In -pvc
#     mode latexmk then watches the real sources (main.tex, capitoli/*.tex,
#     references.bib, template/*) and writes main.pdf, main.synctex.gz and
#     every .aux file next to main.tex — exactly where LaTeX Workshop looks
#     for them (latex-workshop.latex.outDir = %DIR%). Intellisense, SyncTeX
#     and the viewer refresh on Ctrl+S work out of the box.
#   * Keep the substituted covermatter files OUT of the working tree: they
#     are generated into a random /tmp directory (mode 0700) and exposed to
#     the TeX engine only via TEXINPUTS/BIBINPUTS/BSTINPUTS.
#   * latexmk settings must be PACKAGE variables: latexmk only sees $main::*,
#     so `my $pdflatex = ...` would be silently ignored.
#   * Clean up the temp dir on exit and on INT/TERM/HUP (LaTeX Workshop kills
#     the -pvc process when the build is stopped).
# ---------------------------------------------------------------------------

use warnings;
no warnings 'once';   # $pdf_mode/$pdflatex are read by latexmk, not by this file
use utf8;
use JSON::PP;
use File::Path qw(make_path remove_tree);
use File::Copy qw(cp);
use File::Temp qw(tempdir);
use Cwd;

# Project root: the directory latexmk is started from. LaTeX Workshop always
# starts latexmk in the root file's directory, i.e. the repository root.
my $project_dir = getcwd();

# Private temp dir holding ONLY the generated covermatter files.
my $keep_temp = $ENV{'KEEP_TEMP'} // 0;
my $temp_base = tempdir(DIR => '/tmp', CLEANUP => 0);   # created with 0700
my $gen_cm    = "$temp_base/__COVERMATTER__";
make_path($gen_cm, { mode => 0700 });

# --- Generate covermatter files from template/ + substitutions.json ---------
if (-f "$project_dir/substitutions.json") {
    open my $fh, '<:raw', "$project_dir/substitutions.json" or die $!;
    my $json_bytes = do { local $/; <$fh> };
    close $fh;

    my $config = decode_json($json_bytes);
    while (my ($rel_path, $subs) = each %$config) {
        my $dest_path = $gen_cm . substr($rel_path, index($rel_path, '/'));

        if ($rel_path eq 'covermatter/dedica.tex') {
            my $quote  = $subs->{quote}  // '';
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
        my $src = "$project_dir/template/$rel_path";
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

# --- Covermatter figures: personal covermatter/figure, then the template's --
sub copy_figure_dir {
    my ($src_dir) = @_;
    return unless -d $src_dir;
    make_path("$gen_cm/figure", { mode => 0700 });
    opendir my $dh, $src_dir or return;
    while (my $file = readdir($dh)) {
        next if $file =~ /^\./;
        cp("$src_dir/$file", "$gen_cm/figure/$file")
            or warn "Failed to copy $src_dir/$file: $!";
    }
    closedir $dh;
}
copy_figure_dir("$project_dir/covermatter/figure");
copy_figure_dir("$project_dir/template/covermatter/figure");

# ---------------------------------------------------------------------------
# Make the generated covermatter and the template styles visible to the
# compiler. '.' comes first so project files always win; '//' means recursive
# search, so `__COVERMATTER__/frontespizio` resolves to
# $temp_base/__COVERMATTER__/frontespizio.tex and `packages.sty` to
# template/packages.sty; the trailing ':' keeps kpathsea's default path.
# ---------------------------------------------------------------------------
my $template_dir = "$project_dir/template";
$ENV{'TEXINPUTS'} = ".:$temp_base//:$template_dir//:" . ($ENV{'TEXINPUTS'} // '');
$ENV{'BIBINPUTS'} = ".:$temp_base//:"                 . ($ENV{'BIBINPUTS'} // '');
$ENV{'BSTINPUTS'} = ".:$template_dir//:"              . ($ENV{'BSTINPUTS'} // '');

# ---------------------------------------------------------------------------
# Build configuration (package variables — see note at the top).
# -synctex=1: SyncTeX data for LaTeX Workshop's click-to-jump.
# -shell-escape: required by minted.
# $pdf_previewer = 'NONE': never spawn an external viewer in -pvc mode;
# LaTeX Workshop's own viewer watches main.pdf and refreshes it on save.
# ---------------------------------------------------------------------------
$pdf_mode = 1;
$pdflatex = 'pdflatex -synctex=1 -shell-escape -interaction=nonstopmode %O %S';
$pdf_previewer = 'NONE';

# ---------------------------------------------------------------------------
# Remove the private temp dir on exit and when the -pvc process is stopped.
# Set KEEP_TEMP=1 to keep it for debugging.
# ---------------------------------------------------------------------------
sub cleanup_temp {
    return unless $temp_base && -d $temp_base && !$keep_temp;
    remove_tree($temp_base, { verbose => 0 });
}
END { cleanup_temp() }
$SIG{INT}  = sub { cleanup_temp(); exit 1 };
$SIG{TERM} = sub { cleanup_temp(); exit 1 };
$SIG{HUP}  = sub { cleanup_temp(); exit 1 };
