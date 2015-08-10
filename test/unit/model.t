#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use FindBin qw($Bin);
use lib "$Bin/.."; #location of includes.pm
use includes; #file with paths to PsN packages

use model;
use PsN;			# Need to set PsN version as this is a global variable
$PsN::nm_major_version = 7;
my $ver = $PsN::nm_major_version;

my $modeldir = $includes::testfiledir;

my $model = model->new(filename => "$modeldir/warfarin_saem_noest.mod", ignore_missing_data => 1);
#print "is est ".$model->is_estimation(problem_number => 1)."\n";
is ($model->get_estimation_evaluation_problem_number,-1,"get_estimation_evaluation_problem_number saem-foci");

$model = model->new(filename => "$modeldir/pheno.mod");

is ($model->get_estimation_evaluation_problem_number,1,"get_estimation_evaluation_problem_number");

is (scalar(@{$model->problems}), 1, "Check number of problems");
my $problem = $model->problems->[0];
is (scalar(@{$problem->inputs}), 1, "Check number of inputs");
my $options = $model->problems->[0]->inputs->[0]->options;
is (scalar(@{$options}), 6, "Check number of options for inputs");

# Names of input options
my @input_option_names = qw(ID TIME AMT WGT APGR DV);

for (my $i = 0; $i < @input_option_names; $i++) {
	is ($options->[$i]->name, $input_option_names[$i], "Check \$INPUT options name $i");
	is ($options->[$i]->value, '', "Check \$INPUT options value $i");
}

# ouput_files method
my @output_files = qw(pheno.lst pheno.ext pheno.cov pheno.cor pheno.coi pheno.phi pheno.phm pheno.shk pheno.grd pheno.xml pheno.cnv pheno.smt pheno.rmt 
pheno.imp pheno.npd pheno.npe pheno.npi pheno.fgh pheno.log.xml pheno.cpu pheno.shm pheno.agh patab1 phenomsf);

my $files = $model->output_files;
use Data::Dumper;
print Dumper($files);

for (my $i = 0; $i < @output_files; $i++) {
	is ($$files[$i], $output_files[$i], "output_files method $i");
}

# get_coordslabels method
my $coordslabels = $model->get_coordslabels(parameter_type => 'theta');
is ((sort keys %{$$coordslabels[0]})[0], 'THETA1', 'get_coordslabels theta 1');
is ((sort keys %{$$coordslabels[0]})[1], 'THETA2', 'get_coordslabels theta 2');
is ((sort values %{$$coordslabels[0]})[0], 'CL', 'get_coordslabels theta 3');
is ((sort values %{$$coordslabels[0]})[1], 'V', 'get_coordslabels theta 4');

$coordslabels = $model->get_coordslabels(parameter_type => 'omega');
is ((sort keys %{$$coordslabels[0]})[0], 'OMEGA(1,1)', 'get_coordslabels omega 1');
is ((sort keys %{$$coordslabels[0]})[1], 'OMEGA(2,2)', 'get_coordslabels omega 2');
is ((sort values %{$$coordslabels[0]})[0], 'IVCL', 'get_coordslabels omega 3');
is ((sort values %{$$coordslabels[0]})[1], 'IVV', 'get_coordslabels omega 4');

# idcolumns method
my $columns = $model->idcolumns(problem_numbers => [0]);

is ($$columns[0], 1, "idcolumns method");

# is_option_set method
ok ($model->is_option_set(record => 'input', name => 'APGR'), "is_option_set \$INPUT");
ok ($model->is_option_set(record => 'estimation', name => 'MAXEVALS'), "is_option_set \$INPUT");
ok (!$model->is_option_set(record => 'input', name => 'OPEL'), "is_option_set \$INPUT");

#setup_filter method
my @header = ('method','model','problem','significant_digits','minimization_successful','covariance_step_successful','ofv');
my @filter = ('minimization_successful.eq.1','significant_digits.gt.4','problem.lt.2','covariance_step_successful.ne.0');
my ($indices,$relations,$value) = model::setup_filter(filter => \@filter, header => \@header);
is_deeply($indices,[4,3,2,5], "setup_filter method, finding columns");
is_deeply($relations,['==','>','<','!='], "setup_filter method, finding relations");
is_deeply($value,[1,4,2,0], "setup_filter method, finding values");

@filter = ('method.eq.bootstrap');
($indices,$relations,$value) = model::setup_filter(filter => \@filter, header => \@header, string_filter => 1);
is ($indices->[0],0,"setup_filter method, method index");
is ($relations->[0],'eq',"setup_filter method, method relation");
is ($value->[0],'bootstrap',"setup_filter method, method value");

#method get_rawres_parameter_indices
my $hashref = model::get_rawres_parameter_indices(filename => $modeldir.'/raw_results_structure_for_model_test');
is_deeply($hashref->{'theta'},[20,21],'method get_rawres_parameter_indices 1, theta');
is_deeply($hashref->{'omega'},[22,23],'method get_rawres_parameter_indices 1, omega');
is_deeply($hashref->{'sigma'},[24],'method get_rawres_parameter_indices 1, sigma');
$hashref = model::get_rawres_parameter_indices(filename => 'raw_results_structure_for_model_test',
											   directory => $modeldir);
is_deeply($hashref->{'theta'},[20,21],'method get_rawres_parameter_indices 2, theta');
is_deeply($hashref->{'omega'},[22,23],'method get_rawres_parameter_indices 2, omega');
is_deeply($hashref->{'sigma'},[24],'method get_rawres_parameter_indices 2, sigma');

#get_rawres_params method
#here $model must still refer to pheno.mod, otherwise test will fail

my ($arr,$hashref) = model::get_rawres_params(filename => $modeldir.'/rawres_for_get_rawres_params.csv',
											  string_filter => ['method.eq.bootstrap'],
											  filter => ['significant_digits.gt.4'],
											  require_numeric_ofv => 1,
											  offset => 1,
											  model => $model);
is (scalar(@{$arr}),3,'method get_rawres_params, number of lines returned ');
is($arr->[0]->{'theta'}->{'CL'},1.1,'method get_rawres_params, theta 0');
is($arr->[0]->{'theta'}->{'V'},1.2,'method get_rawres_params, theta 0');
is($arr->[1]->{'theta'}->{'CL'},2.1,'method get_rawres_params, theta 1');
is($arr->[1]->{'theta'}->{'V'},2.2,'method get_rawres_params, theta 1');
is($arr->[2]->{'theta'}->{'CL'},3.1,'method get_rawres_params, theta 2');
is($arr->[2]->{'theta'}->{'V'},3.2,'method get_rawres_params, theta 2');
is($arr->[0]->{'omega'}->{'IVCL'},1.3,'method get_rawres_params, omega 0');
is($arr->[0]->{'omega'}->{'IVV'},1.4,'method get_rawres_params, omega 0');
is($arr->[1]->{'omega'}->{'IVCL'},2.3,'method get_rawres_params, omega 1');
is($arr->[1]->{'omega'}->{'IVV'},2.4,'method get_rawres_params, omega 1');
is($arr->[2]->{'omega'}->{'IVCL'},3.3,'method get_rawres_params, omega 2');
is($arr->[2]->{'omega'}->{'IVV'},3.4,'method get_rawres_params, omega 2');
is($arr->[0]->{'sigma'}->{"SIGMA(1,1)"},1.5,'method get_rawres_params, sigma 0');
is($arr->[1]->{'sigma'}->{"SIGMA(1,1)"},2.5,'method get_rawres_params, sigma 1');
is($arr->[2]->{'sigma'}->{"SIGMA(1,1)"},3.5,'method get_rawres_params, sigma 2');
is($arr->[0]->{'ofv'},752.0400284856,'method get_rawres_params, ofv 0');
is($arr->[1]->{'ofv'},761.1429095868,'method get_rawres_params, ofv 1');
is($arr->[2]->{'ofv'},674.1097668967,'method get_rawres_params, ofv 2');
is($arr->[0]->{'model'},1,'method get_rawres_params, model 0');
is($arr->[1]->{'model'},2,'method get_rawres_params, model 1');
is($arr->[2]->{'model'},5,'method get_rawres_params, model 2');



my $vectorsamples = $model->create_vectorsamples(sampled_params_arr => $arr);
is($vectorsamples->[0]->[0],1.1,'create vectorsamples 0,0');
is($vectorsamples->[0]->[1],1.2,'create vectorsamples 0,1');
is($vectorsamples->[0]->[2],1.3,'create vectorsamples 0,2');
is($vectorsamples->[0]->[3],1.4,'create vectorsamples 0,3');
is($vectorsamples->[0]->[4],1.5,'create vectorsamples 0,4');
is($vectorsamples->[1]->[0],2.1,'create vectorsamples 1,0');
is($vectorsamples->[1]->[1],2.2,'create vectorsamples 1,1');
is($vectorsamples->[1]->[2],2.3,'create vectorsamples 1,2');
is($vectorsamples->[1]->[3],2.4,'create vectorsamples 1,3');
is($vectorsamples->[1]->[4],2.5,'create vectorsamples 1,4');
is($vectorsamples->[2]->[0],3.1,'create vectorsamples 2,0');
is($vectorsamples->[2]->[1],3.2,'create vectorsamples 2,1');
is($vectorsamples->[2]->[2],3.3,'create vectorsamples 2,2');
is($vectorsamples->[2]->[3],3.4,'create vectorsamples 2,3');
is($vectorsamples->[2]->[4],3.5,'create vectorsamples 2,4');

($arr,$hashref) = model::get_rawres_params(filename => $modeldir.'/rawres_for_get_rawres_params.csv',
										   string_filter => ['method.eq.bootstrap'],
										   require_numeric_ofv => 1,
										   offset => 1,
										   rawres_structure_filename => $modeldir.'/rawres_for_get_rawres_params_structure');
is($arr->[0]->{'theta'}->{'CL'},1.1,'method get_rawres_params, theta 0 b');
is($arr->[0]->{'theta'}->{'V'},1.2,'method get_rawres_params, theta 0 b');
is($arr->[1]->{'omega'}->{'IVCL'},2.3,'method get_rawres_params, omega 1 b');
is($arr->[2]->{'sigma'}->{"SIGMA(1,1)"},0.05,'method get_rawres_params, sigma 2 b');
is($arr->[3]->{'omega'}->{'IVV'},3.4,'method get_rawres_params, omega 1 b');

# set_maxeval_zero


is ($model->get_option_value(record_name => 'estimation', option_name => 'MAXEVALS'), 9997, "before set_maxeval_zero");
$model->set_maxeval_zero;
is ($model->get_option_value(record_name => 'estimation', option_name => 'MAXEVALS'), 0, "before set_maxeval_zero");

$model->add_records( type  => 'estimation', record_strings => ['METHOD=IMP'] );
is ($model->get_option_value(record_name => 'estimation', option_name => 'METHOD', record_index => 1), 'IMP', "added estimation record");

$model->set_maxeval_zero;

ok ($model->is_option_set(record => 'estimation', name => 'POSTHOC'), "set_maxeval_zero: transferred option");
is ($model->problems->[0]->estimations->[1], undef, "set_maxeval_zero: Removed estimation");

# update_inits
$model = model->new(filename => "$modeldir/pheno.mod");

$model->update_inits(from_output_file => "$modeldir/pheno_test.lst");

my $lines = $model->record(record_name => 'sigma');
ok ($lines->[0]->[0] =~ 0.0164, "update_inits: new sigma");

is ($model->problems->[0]->thetas->[0]->options->[0]->lobnd, 0, "update_inits: new theta lobnd");
is ($model->problems->[0]->thetas->[0]->options->[0]->init, 0.00555, "update_inits: new theta init");
is ($model->problems->[0]->thetas->[1]->options->[0]->lobnd, 0, "update_inits: new theta lobnd");
is ($model->problems->[0]->thetas->[1]->options->[0]->init, 1.34, "update_inits: new theta init");

# has_code
$model = model->new(filename => "$modeldir/pheno.mod");

ok ($model->has_code(record => 'pk'), "has_code pk record");
ok (not ($model->has_code(record => 'pred')), "has_code pred record");

# set_code / get_code
$model = model->new(filename => "$modeldir/pheno.mod");

my $code = [ "TSTCDE", "ROW2" ];

$model->set_code(record => 'pk', code => $code);

my $new_code = $model->get_code(record => 'pk');

is ($new_code->[0], $code->[0], "set_code row 0");
is ($new_code->[1], $code->[1], "set_code row 1");

# create_output_filename
my $dummy = model->create_dummy_model;

$dummy->filename('test.mod');
is($dummy->create_output_filename, 'test.lst', "create_output_filename .mod name");
$dummy->filename('test.mod.mod');
is($dummy->create_output_filename, 'test.mod.lst', "create_output_filename multiple .mod extensions");
$dummy->filename('test.ctl');
is($dummy->create_output_filename, 'test.lst', "create_output_filename .ctl name");
$dummy->filename('model');
is($dummy->create_output_filename, 'model.lst', "create_output_filename no extension");

$model = model->new(filename => "$modeldir/mox_sir_block2.mod");
is ($model->get_estimation_evaluation_problem_number,1,"get_estimation_evaluation_problem_number");
is_deeply($model->fixed_or_same(parameter_type => 'theta')->[0],[0,0,0,0,0],'fixed or same theta ');
is_deeply($model->fixed_or_same(parameter_type => 'omega')->[0],[0,0,0,0],'fixed or same omega ');
is_deeply($model->same(parameter_type => 'omega')->[0],[0,0,0,0],'same omega 1');
is_deeply($model->fixed_or_same(parameter_type => 'sigma')->[0],[1],'fixed or same sigma ');
is_deeply($model->same(parameter_type => 'sigma')->[0],[0],'same sigma 1');

$model = model->new(filename => "$modeldir/tbs1.mod");
is_deeply($model->fixed_or_same(parameter_type => 'omega')->[0],[0,0,0,0,0,1,0,1],'fixed or same omega 2');
is_deeply($model->fixed_or_same(parameter_type => 'sigma')->[0],[1],'fixed or same sigma 2');
is_deeply($model->same(parameter_type => 'omega')->[0],[0,0,0,0,0,1,0,1],'same omega 2');
is_deeply($model->same(parameter_type => 'sigma')->[0],[0],'same sigma 2');

$model = model->new(filename => "$modeldir/tnpri.mod");
is ($model->get_estimation_evaluation_problem_number,-1,"get_estimation_evaluation_problem_number");

$model = model->new(filename => "$modeldir/twoprobmsf_match.mod", ignore_missing_data =>1);
is ($model->msfo_to_msfi_mismatch,0,"msfo_to_msfi_mismatch false");
$model = model->new(filename => "$modeldir/twoprobmsf_mismatch.mod", ignore_missing_data =>1);
is ($model->msfo_to_msfi_mismatch,2,"msfo_to_msfi_mismatch true second prob");


# Test of different models

#pheno_multiple_sizes
lives_ok { my $model = model->new(filename => "$modeldir/model/pheno_multiple_sizes.mod") } "multiple sizes should not crash";
dies_ok { my $model = model->new(filename => "$modeldir/model/pheno_multiple_sizes_not_in_beginning.mod") } "one sizes not in beginning";


$model = model->new(filename => "$modeldir/pheno_flip_comments.mod");

my $flipped = model::flip_comments(from_model => $model,
								   new_file_name => "$modeldir/model/flip.mod",
								   write => 0);

is_deeply($model->datafiles(absolute_path=>1),$flipped->datafiles(absolute_path=>1),"same datafile abspath after flip_comments");

my ($dir,$file)=OSspecific::absolute_path($model->directory.'/model','file'); 
my ($dir2,$file2)=OSspecific::absolute_path($flipped->directory,'file'); 
is($dir,$dir2,'flip_comments output model in subdir');


done_testing();
