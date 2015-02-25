package tool::precond;

use include_modules;
use Math::Random;
use Math::Trig;
use File::Spec;
use Moose;
use MooseX::Params::Validate;
use File::Copy qw(copy);

use array qw(:all);
use tool::modelfit;
use linear_algebra;
use output;
use Storable qw(dclone);

extends 'tool';

has 'precond_matrix' => (is => 'rw', isa => 'ArrayRef[ArrayRef]');
has 'precond_model' => (is => 'rw', isa => 'model');
has 'update_model' => (is => 'rw', isa => 'Maybe[Str]');
has 'negaEigenIndex' =>  (is => 'rw', isa => 'ArrayRef');
has '_repara_model' => (is => 'rw', isa => 'model');


sub BUILD
{
	my $self = shift;

	my $records = $self->precond_model->problems->[0]->covariances;
	unless (defined $records and defined $records->[0]) {
		croak("No \$COVARIANCE defined in " . $self->precond_model->full_name . "\nPlease add it to the model and run again.");
	}
}

sub modelfit_setup
{
	my $self = shift;

	my $model_filename = $self->precond_model->filename;
	$model_filename =~ s/(\.ctl|\.mod)$//;
	$model_filename .= '_repara.mod';
	$model_filename = File::Spec->catfile(($self->directory, "m1"), $model_filename);
	
    my $model = create_reparametrized_model(
		filename => $model_filename,
		model => $self->precond_model,
		precond_matrix => $self->precond_matrix,
		negaEigenIndex => $self->negaEigenIndex,
		directory => $self->directory,
	);

    # FIXME: Use cov matrix already in memory
    my %hash = %{common_options::restore_options(@common_options::tool_options)};
	my $nmoutopt = $hash{'nm_output'};
	if (defined $nmoutopt and length($nmoutopt) > 0) {
		$nmoutopt .= ',cov'; #ok to append even if there already
	} else {
		$nmoutopt = 'cov';
	}

    my $modelfit = tool::modelfit->new(
		%{common_options::restore_options(@common_options::tool_options)},
		models => [ $model ], 
		base_dir => $self->directory,
		directory => undef,
		top_tool => 0,
        nm_output => $nmoutopt,
	);

	$self->_repara_model($model);

	$self->tools([]) unless defined $self->tools;
	push(@{$self->tools}, $modelfit);
}

sub modelfit_analyze
{
    my $self = shift;

    my $filename = $self->_repara_model->filename;
    $filename =~ s/\.mod$/.cov/;
    my $cov_filename = 'm1/' . $filename;

	my $model_filename = $self->precond_model->filename;
	$model_filename =~ s/(\.ctl|\.mod)$//;
    my $result_cov = $model_filename . '.cov';

    my $cov_matrix = convert_reparametrized_cov(
        cov_filename => $cov_filename,
        model => $self->precond_model,
        precond_matrix => $self->precond_matrix,
        output_filename => $result_cov,
		directory => $self->directory
    );

    if ($self->nm_output =~ /(^|,)cov(,|$)/) {
        copy($result_cov, "..");
    }

    if ($self->_repara_model->is_run) {
        my $output = $self->_repara_model->outputs->[0];

        my $copy = $self->precond_model->copy(
            filename => 'updated_model.mod',
            copy_datafile => 0,
            write_copy => 0,
            copy_output => 0
        );

        my $theta = $output->get_single_value(attribute => 'thetas');
        my $new_theta = [];

        # Multiply precond_matrix with theta to obtain original theta
        for (my $row = 0; $row < scalar(@$theta); $row++) {
            my $sum = 0;
            for (my $col = 0; $col < scalar(@$theta); $col++) {
                $sum += $self->precond_matrix->[$row]->[$col] * $theta->[$col];
            }
            $new_theta->[$row] = $sum;
        }

        my $theta_ind = 0;
        for my $theta (@{$copy->problems->[0]->thetas}) {
            for (my $i = 0; $i < scalar(@{$theta->options}); $i++) {
                my $option = $theta->options->[$i];
                $option->init($new_theta->[$theta_ind]);
                if (defined $option->lobnd and $new_theta->[$theta_ind] < $option->lobnd) {
                    $option->clear_lobnd;
                    print "Warning: updated THETA(", $i + 1, ") estimate is below original lower bound. The bound will be removed in updated model.\n";
                }
                if (defined $option->upbnd and $new_theta->[$theta_ind] > $option->upbnd) {
                    $option->clear_upbnd;
                    print "Warning: updated THETA(", $i + 1, ") estimate is above original upper bound. The bound will be removed in updated model.\n";
                }
                $theta_ind++;
            }
        }

        $copy->_write;
        if (defined $self->update_model) {
            copy $copy->full_name, '../' . $self->update_model;
        }


        # Print raw results
        my $modelfit = $self->tools->[0];
        my $filename = $self->precond_model->filename;
        $filename =~ s/.mod$/.csv/;
        $filename = "raw_results_" . $filename;
        $modelfit->directory(".");
        $modelfit->raw_results_file->[0] = $filename;

        my $theta_pos = $modelfit->raw_line_structure->{1}->{theta};
        $theta_pos =~ s/(.*),.*/$1/;
        for (my $i = 0; $i < @$new_theta; $i++) {
            $modelfit->raw_results->[0]->[$theta_pos + $i] = $new_theta->[$i];
        }
        my $se_pos = $modelfit->raw_line_structure->{1}->{setheta};
        $se_pos =~ s/(.*),.*/$1/;

		my $covSuccess=0;
		
		for (my $i=0; $i<@$new_theta;$i++){
			if ($cov_matrix->[$i]->[$i] !=0){
				$covSuccess=1;
			}
		}
		
        
		if ($covSuccess==0){
			for (my $i = 0; $i < @$new_theta; $i++) {
				$modelfit->raw_results->[0]->[$se_pos + $i] = "NA";
			}
		}else{
			for (my $i = 0; $i < @$new_theta; $i++) {
				$modelfit->raw_results->[0]->[$se_pos + $i] = sqrt($cov_matrix->[$i]->[$i]);
			}
			print "\n\n  preconditioning sucessful \n";
		}
            
        

        $modelfit->print_raw_results;

    } else {
        print "Unable to update model: model was not run";
    }
}

sub _reparametrize
{
	my $code = shift;
	my $nthetas = shift;
	my $model = shift;
    
    for (my $i = 0; $i < scalar(@$code); $i++) {
        my $find = "THE_";
        my $replace = "TTHE_";
        $find = quotemeta $find;
        $code->[$i] =~ s/$find/$replace/g;
        
    }
	
    my $fixed = $model->fixed(parameter_type => 'theta');

	for (my $i = 0; $i < scalar(@$code); $i++) {
			for (my $j = 1; $j < $nthetas + 1; $j++) {
				if (!$fixed->[0]->[$j-1]){
					my $find = "THETA($j)";
					my $replace = "THE_$j";
					$find = quotemeta $find;
					$code->[$i] =~ s/$find/$replace/g;
				}
			}
		}
    
}

sub create_reparametrized_model
{
	my %parm = validated_hash(\@_,
		filename => { isa => 'Str', optional => 0 },
		model => { isa => 'model' },
        precond_matrix => { isa => 'ArrayRef[ArrayRef]' },
 		negaEigenIndex=> {isa => 'rw', isa => 'ArrayRef'},
		directory =>  { isa => 'Str'},
	);
	my $filename = $parm{'filename'};
	my $model = $parm{'model'};
	my @precond_matrix = @{$parm{'precond_matrix'}};	my @negaEigenIndex = @{$parm{'negaEigenIndex'}};
	my $directory = $parm{'directory'};

	my $model = $model->copy(
		output_same_directory => 1,
		filename => $filename,
		copy_datafile => 0,
		write_copy => 0,
		copy_output => 0
	);

    if (not $model->is_option_set(record => 'covariance', name => 'UNCONDITIONAL', fuzzy_match => 1)) {
        $model->add_option(record_name => 'covariance', option_name => 'UNCONDITIONAL');
    }

    if (not $model->is_option_set(record => 'estimation', name => 'FORMAT', fuzzy_match => 1)) {
        $model->add_option(record_name => 'estimation', option_name => 'FORMAT', option_value => 's1PE23.16');
    }

	my @code;
	my $code_record;
	if ($model->has_code(record => 'pk')) {
		@code = @{$model->get_code(record => 'pk')};
		$code_record = 'pk';
	} elsif ($model->has_code(record => 'pred')) {
		@code = @{$model->get_code(record => 'pred')};
		$code_record = 'pred';
	} else {
		croak("Neither PK nor PRED defined in " . $model->filename . "\n");
	}

	_reparametrize(\@code, $model->nthetas, $model);

	my $tempString;
	my $tempTempSt;
	
    my $fixed = $model->fixed(parameter_type => 'theta');

	for (my $i = 0; $i < $model->nthetas; $i++) {
		if (!$fixed->[0]->[$i]){

		$tempString = 'THE_' . ($i + 1) . '=';
		my @temp=@{$precond_matrix[$i]};
		for (my $j = 0; $j < scalar(@temp); $j++) {
			if ($j == 0 or $precond_matrix[$i][$j] < -0.000000000000001) {
				if (length($tempString) + length($precond_matrix[$i][$j] . '*THETA(' . ($j + 1) . ')') > 70) {
					$tempString = $tempString . "\n";
					$tempTempSt = $tempTempSt . $tempString;
					$tempString = 'THE_'.($i + 1) . '=THE_' . ($i + 1) . $precond_matrix[$i][$j] . '*THETA(' . ($j + 1) . ')';
				} else {
					$tempString = $tempString . $precond_matrix[$i][$j] . '*THETA(' . ($j + 1) . ')';
				}
			} elsif ($precond_matrix[$i][$j] > 0.000000000000001) {
				if (length($tempString) + length($precond_matrix[$i][$j] . '*THETA(' . ($j + 1) . ')') > 70) {
					$tempString = $tempString . "\n";
					$tempTempSt = $tempTempSt . $tempString;
					$tempString = 'THE_' . ($i + 1) . '=THE_' . ($i + 1) . '+' . $precond_matrix[$i][$j] . '*THETA(' . ($j + 1) . ')';
				} else {
					$tempString = $tempString . '+' . $precond_matrix[$i][$j] . '*THETA(' . ($j + 1) . ')';
				}
			}
		}
		$tempString = $tempString . "\n";
		$tempTempSt = $tempTempSt . $tempString;
		}
	}

    # Make sure reparametrization is only done when THETAs have changed
    $tempTempSt = "IF (NEWIND == 0) THEN\n" . $tempTempSt . "END IF\n";

	unshift @code, $tempTempSt;

	$model->set_code(record => $code_record, code => \@code);

	# Reparametrize other blocks of abbreviated code
	for my $record (('error', 'des', 'aes', 'aesinitial', 'mix', 'infn')) {
		if ($model->has_code(record => $record)) {  
			my $code = $model->get_code(record => $record);
			_reparametrize($code, $model->nthetas, $model);
			$model->set_code(record => $record, code => $code);
		}
	}

	# Remove limits for thetas
    foreach my $theta (@{$model->problems->[0]->thetas}) {
       	foreach my $option (@{$theta->options}) {
    		$option->clear_upbnd;
    		$option->clear_lobnd;
    	}
    }

	# Set new initial values for thetas
	my @parameter_initial = @{$model->initial_values(parameter_type => 'theta')->[0]};
    my @dummie_parameter_initial = @{$model->initial_values(parameter_type => 'theta')->[0]};

	my @parameter_initial_copy;
	
	for(my $i=0; $i<scalar(@precond_matrix);$i++){
		$parameter_initial_copy[$i]=$parameter_initial[$i];
	}

    # Clone to be not overwrite precond_matrix
    my $ref = dclone(\@precond_matrix);
    @precond_matrix = (@$ref);

    
    my $offDiag=0;
    my $diagSum=0;
    my $offDigTemp=0;
    my @diagElement;
    
    for (my $k = 0; $k < scalar(@parameter_initial); $k++) {
        $diagElement[$k]=0;
        
        for (my $i = 0; $i < scalar(@parameter_initial); $i++) {
            $parameter_initial[$i]=0;
            for (my $j = 0 ; $j < scalar(@parameter_initial); $j++) {
                if ($k==$i){
                    $diagSum=$diagSum+($precond_matrix[$j][$k]*$precond_matrix[$j][$i]);
                    $diagElement[$i]=$diagElement[$i]+$precond_matrix[$j][$k]*$precond_matrix[$j][$i];
                }else{
                    $offDigTemp=$offDigTemp+($precond_matrix[$j][$k]*$precond_matrix[$j][$i]);
                }
            }
            $offDiag=$offDiag+abs($offDigTemp);
            $offDigTemp=0;
        }
    }

    
    if ($offDiag<0.000001){  # if precond_matrix is orthogonal up to scaling
      for (my $i = 0; $i < scalar(@parameter_initial); $i++) {
        $parameter_initial[$i]=0;
        for (my $j = 0 ; $j < scalar(@parameter_initial); $j++) {
            $parameter_initial[$i]=$parameter_initial[$i]+$dummie_parameter_initial[$j]*$precond_matrix[$j][$i];
        }
        $parameter_initial_copy[$i]=$parameter_initial[$i]/$diagElement[$i];
		#if ($eigenValues[$i]<0){
		#	$parameter_initial[$i]=$parameter_initial[$i]+$eigenValues[$i];
		#}
      }
    }else{ # if precond_matrix is not orthogonal up to scaling

        linear_algebra::LU_factorization(\@precond_matrix);
        
        for (my $i = 1; $i < scalar(@precond_matrix); $i++) {
        	for (my $j = 0; $j < $i; $j++) {
                $parameter_initial_copy[$i] = $parameter_initial_copy[$i] - $parameter_initial_copy[$j] * $precond_matrix[$i][$j];
            }        }        
        for (my $i = scalar(@precond_matrix)-1; $i >= 0; $i--) {
        	for (my $j = scalar(@precond_matrix)-1; $j > $i; $j--){
                $parameter_initial_copy[$i] = $parameter_initial_copy[$i] - $parameter_initial_copy[$j] * $precond_matrix[$i][$j];
         		}
        	$parameter_initial_copy[$i] = $parameter_initial_copy[$i]/$precond_matrix[$i][$i];
        }
    }

	if (scalar(@negaEigenIndex)>0){
		
		print "\n\nPerturbed indices: ";
			 
			for (my $i=0; $i<scalar(@negaEigenIndex); $i++){
				print $negaEigenIndex[$i];
				print " ";
				$parameter_initial_copy[$negaEigenIndex[$i]]=$parameter_initial_copy[$negaEigenIndex[$i]]+1;
			}

	}
    
	
	$model->initial_values(parameter_type => 'theta', new_values => [[@parameter_initial_copy]]);


    # Increase NMTRAN limits on the number of intermediate variables and total number of constants
    my $size_value = 100000;
    my %changed_sizes = (DIMCNS => 0, DIMNEW => 0, DIMTMP => 0);
    if (defined $model->problems->[0]->sizess) {
        for my $sizes (@{$model->problems->[0]->sizess}) {
            for my $option (@{$sizes->options}) {
                for my $relevant (keys %changed_sizes) {
                    if ($option->name eq $relevant) {
                        $option->name($relevant);
                        $option->value($size_value);
                        $changed_sizes{$relevant} = 1;
                    }
                }
            }
        }
    }
    my @record_strings = ();
    for my $name (keys %changed_sizes) {
        if (not $changed_sizes{$name}) {
            push @record_strings, "$name=$size_value";
        }
    }

    if (@record_strings) {
        $model->problems->[0]->add_records(type => 'sizes', record_strings => \@record_strings );
    }

    $model->_write;

	my @precMatSLine;
	my @line_values;
	for (my $i = 0; $i < $model->nthetas; $i++) {
		for (my $j = 0; $j < $model->nthetas; $j++) {
			$line_values[$j]=$precond_matrix[$i][$j];
			if ($line_values[$j] < 0) {
				$line_values[$j] = sprintf(" %.17E", $line_values[$j]);
			} else {
				$line_values[$j] = sprintf("  %.17E", $line_values[$j]);
			}
		}
		$precMatSLine[$i] = join " ", @line_values;
	}

	open (my $MYFILE, '>', File::Spec->catfile($directory, "precMatrix"));
	for (my $i = 0; $i < scalar(@precMatSLine); $i++) {
		print $MYFILE $precMatSLine[$i] . "\n";
	}

	close $MYFILE; 


	return $model;
}

sub convert_reparametrized_cov
{
	my %parm = validated_hash(\@_,
		cov_filename => { isa => 'Str' },
		model => { isa => 'model' },
		precond_matrix => { isa => 'ArrayRef[ArrayRef]' },
		output_filename => { isa => 'Str' },
		directory => { isa => 'Str' },

	);
	my $cov_filename = $parm{'cov_filename'};
	my $model = $parm{'model'};
	my @precond_matrix = @{$parm{'precond_matrix'}};
	my $output_filename = $parm{'output_filename'};
	my $directory = $parm{'directory'};

	my @cov_lines;
	
	
	if (-e $cov_filename) {
	
	open(my $fh, '<', $cov_filename) or croak("Cannot find the .cov file '$cov_filename' [$!]\n");
	while (my $tline = <$fh>) {
		chomp $tline;
		push @cov_lines, $tline;
	}

	my @reparaCov;

	my $rowCount = 0;
	my $found_table;
	my @header_labels;
	my $header_ok;
	my $given_header_warning;

	for (my $k = 0; $k < scalar(@cov_lines); $k++) {
		my $line = $cov_lines[$k]; 
		if ($line =~ /^\s*TABLE NO.\s+(\d+):/) {
			croak("two tables found where 1 expected") if $found_table;
			$found_table = 1;
		} elsif ($line =~ /^\s*NAME/ ) {
			$line =~ s/^\s*//; #get rid of leading spaces
			@header_labels = split /\s+/, $line;
			$header_ok = 1 if ($header_labels[0] eq 'NAME');
		} else {
			unless ((scalar(@header_labels > 2)) or $given_header_warning or $header_ok) {
				my $mes = "\n\n\***Warning***\n".
				"Too few elements in parameter label array in additional output file. ".
				"Is label row missing, or is the ".
				"delimiter something other than spaces (default)? ".
				"Parsing is likely to fail".
				"\n*************\n";
				print $mes;
				$given_header_warning = 1;
			}
			$line =~ s/^\s*//; #get rid of leading spaces
			my @line_values = split /\s+/,$line;
			my $max_column;

			my @new_line;
			$max_column = scalar(@header_labels) ; #store full matrix
			for (my $j = 0; $j < $max_column; $j++) {
				my $i = $j + 1; #must permute omega-sigma
				if ($line_values[$i] eq 'NaN') {
					push(@new_line, undef);
					$reparaCov[$rowCount][$j]=undef;
				} else {
					push(@new_line, eval($line_values[$i]));
					$reparaCov[$rowCount][$j]=eval($line_values[$i]);
				}

			}
			$rowCount++;
		}
	}

	my @temp_varcovMatrix;
	for (my $i = 0; $i < $model->nthetas; $i++) {
		for (my $j = 0; $j < $model->nthetas; $j++) {
			$temp_varcovMatrix[$i][$j] = 0;
			for (my $k = 0; $k < $model->nthetas; $k++) {
				$temp_varcovMatrix[$i][$j] = $temp_varcovMatrix[$i][$j] + $precond_matrix[$i][$k] * $reparaCov[$k][$j];
			}
		}
	}

	my @varcovMatrix;

	for (my $i = 0; $i < $model->nthetas; $i++) {
		for (my $j = 0; $j < $model->nthetas; $j++) {
			$varcovMatrix[$i][$j] = 0;
			for (my $k = 0; $k < $model->nthetas; $k++) {
				$varcovMatrix[$i][$j] = $varcovMatrix[$i][$j] + $temp_varcovMatrix[$i][$k] * $precond_matrix[$j][$k];
			}
		}
	}

    #make symmetric to avoid almost symmetry
    for (my $row = 0; $row < @varcovMatrix; $row++) {
        for (my $col = $row + 1; $col < @varcovMatrix; $col++) {
            $varcovMatrix[$row][$col] = $varcovMatrix[$col][$row];
        }
    }

	my $line;
	for (my $i = 0; $i < $model->nthetas; $i++) {
		$line = $cov_lines[$i + 2]; 
		$line =~ s/^\s*//; #get rid of leading spaces
		my @line_values = split /\s+/, $line;
		for (my $j = 0; $j < $model->nthetas; $j++) {
			@line_values[$j + 1] = $varcovMatrix[$i][$j];
		}
        $line_values[0] = $line_values[0] . (" " x (12 - length($line_values[0]) ) ); 
        for my $i (1..@line_values - 1) {
            if ($line_values[$i] < 0) {
                $line_values[$i] = sprintf(" %.17E", $line_values[$i]);
            } else {
                $line_values[$i] = sprintf("  %.17E", $line_values[$i]);
            }
        }
		$cov_lines[$i + 2] = join " ", @line_values;
		$cov_lines[$i + 2] = " ".$cov_lines[$i + 2];
	}

	open (my $MYFILE, '>', $output_filename);
	for (my $i = 0; $i < scalar(@cov_lines); $i++) {
		print $MYFILE $cov_lines[$i] . "\n";
	}

	close $MYFILE; 

    return \@varcovMatrix;

	}else{
		$cov_filename = "modelfit_dir1/NM_run1/psn.rmt";
		
		open(my $fh, '<', $cov_filename) or croak("\nCovariance step of the preconditioned model did not run see .lst file for the reason\n\n");

		while (my $tline = <$fh>) {
				chomp $tline;
				push @cov_lines, $tline;
			}

			my @reparaCov;

			my $rowCount = 0;
			my $found_table;
			my @header_labels;
			my $header_ok;
			my $given_header_warning;

			for (my $k = 0; $k < scalar(@cov_lines); $k++) {
				my $line = $cov_lines[$k]; 
				if ($line =~ /^\s*TABLE NO.\s+(\d+):/) {
					croak("two tables found where 1 expected") if $found_table;
					$found_table = 1;
				} elsif ($line =~ /^\s*NAME/ ) {
					$line =~ s/^\s*//; #get rid of leading spaces
					@header_labels = split /\s+/, $line;
					$header_ok = 1 if ($header_labels[0] eq 'NAME');
				} else {
					unless ((scalar(@header_labels > 2)) or $given_header_warning or $header_ok) {
						my $mes = "\n\n\***Warning***\n".
						"Too few elements in parameter label array in additional output file. ".
						"Is label row missing, or is the ".
						"delimiter something other than spaces (default)? ".
						"Parsing is likely to fail".
						"\n*************\n";
						print $mes;
						$given_header_warning = 1;
					}
					$line =~ s/^\s*//; #get rid of leading spaces
					my @line_values = split /\s+/,$line;
					my $max_column;

					my @new_line;
					$max_column = scalar(@header_labels) ; #store full matrix
					for (my $j = 0; $j < $max_column; $j++) {
						my $i = $j + 1; #must permute omega-sigma
						if ($line_values[$i] eq 'NaN') {
							push(@new_line, undef);
							$reparaCov[$rowCount][$j]=undef;
						} else {
							push(@new_line, eval($line_values[$i]));
							$reparaCov[$rowCount][$j]=eval($line_values[$i]);
						}

					}
					$rowCount++;
				}
			}
			
			my $fixed = $model->fixed(parameter_type => 'theta');
			
			for (my $i=0; $i<scalar(@reparaCov);$i++){
				if ($fixed->[0]->[$i]||$i>$model->nthetas-1){
					$reparaCov[$i][$i]=1;
				}
			}


		
		my @eigenValMatrix = map { [@$_] }@reparaCov;
								
		my $maxInd1=0;
		my $maxInd2=1;
		my $extremeVal=10000;
		my $counter=0;
									
		my @G;
									
		#initialise G to identity matrix
		for (my $index1=0; $index1< scalar(@eigenValMatrix) ;$index1++){
			for (my $index2=0; $index2< $index1 ;$index2++){
				$G[$index1][$index2]=0;
				$G[$index2][$index1]=0;
			}
		$G[$index1][$index1]=1;
		}


#while (abs($extremeVal)>0.0000000001&$counter<100000000) {
            while (abs($extremeVal/$eigenValMatrix[0][0])>0.000001&$counter<1000000){
									    
		   for (my $index1=0; $index1< scalar(@eigenValMatrix) ;$index1++){
		       for (my $index2=$index1+1; $index2< scalar(@eigenValMatrix) ;$index2++){
		           if ((abs($eigenValMatrix[$maxInd1][$maxInd2])<abs($eigenValMatrix[$index1][$index2]))&($index1!=$index2)){
		               $maxInd1=$index1;
		               $maxInd2=$index2;
		                $extremeVal=$eigenValMatrix[$maxInd1][$maxInd2];
					}
				}
			}
			my $theta=(atan(2*$eigenValMatrix[$maxInd1][$maxInd2]/($eigenValMatrix[$maxInd2][$maxInd2]-$eigenValMatrix[$maxInd1][$maxInd1])))/2;
			my $c=cos($theta);
			my $s=sin($theta);
										    
			my @G_copy= map { [@$_] }@G;
			my @R_copy= map { [@$_] }@eigenValMatrix;
											

			for (my $index=0; $index<scalar(@G); $index++){
				$G[$maxInd1][$index]=$c*$G_copy[$maxInd1][$index]-$s*$G_copy[$maxInd2][$index];
				$G[$maxInd2][$index]=$s*$G_copy[$maxInd1][$index]+$c*$G_copy[$maxInd2][$index];
			}
										    
			for (my $index=0; $index<scalar(@eigenValMatrix); $index++){
				$eigenValMatrix[$maxInd1][$index]=$c*$R_copy[$maxInd1][$index]-$s*$R_copy[$maxInd2][$index];
				$eigenValMatrix[$maxInd2][$index]=$s*$R_copy[$maxInd1][$index]+$c*$R_copy[$maxInd2][$index];
			}
											
			my @r1;
			my @r2;

			for (my $index=0; $index<scalar(@eigenValMatrix); $index++){
			   	$r1[$index]= $eigenValMatrix[$index][$maxInd1];
			   	$r2[$index]= $eigenValMatrix[$index][$maxInd2];
			}
											
			my @R_copy2= map { [@$_] }@eigenValMatrix;

			for (my $index=0; $index<scalar(@eigenValMatrix); $index++){
				$eigenValMatrix[$index][$maxInd1]=$c*$R_copy2[$index][$maxInd1]-$s*$R_copy2[$index][$maxInd2];
			    $eigenValMatrix[$index][$maxInd2]=$s*$R_copy2[$index][$maxInd1]+$c*$R_copy2[$index][$maxInd2];
			}
											
			$counter=$counter+1;
		}
									
		my @eigenValues;
									
		my $maxEigen;
		my $minEigen;
		my $negaCounter=0;
		print "\n ===== Eigenvalues of the R-matrix of the preconditioned model ===== \n";
														
		for (my $index=0; $index<$model->nthetas; $index++){
			$eigenValues[$index]=$eigenValMatrix[$index][$index];
			print $eigenValues[$index];
			print "\n";
						
			if ($index==0){
				$maxEigen=abs($eigenValues[$index]);
				$minEigen=abs($eigenValues[$index]);
			}elsif($maxEigen<abs($eigenValues[$index])){
				$maxEigen=abs($eigenValues[$index]);
			}elsif($minEigen>abs($eigenValues[$index])){
				$minEigen=abs($eigenValues[$index]);
			}
										
			if ($eigenValues[$index]<0){
				$negaCounter++;
			}
						
		}
									
		print("Condition Number : 10^");
		print(int(log($maxEigen/$minEigen)/log(10)));
									
		print("\nNumber of negative eigenvalues : ");
		print($negaCounter);
									
		print("\n ================= \n");
					
		my $foldername=(split(/\//, $directory))[-1];
			
		if (int(log($maxEigen/$minEigen)/log(10))<1 and $negaCounter>0){
			print "\nCovariance step of the preconditioned model failed \n\ntry -pre=$foldername -perturbOnly option\n\n";
		}elsif($negaCounter>0){
			print "\nCovariance step of the preconditioned model failed \n\ntry -pre=$foldername -perturb option\n\n";
		}else{
			print "\nCovariance step of the preconditioned model failed \n\ntry -pre=$foldername option\n\n";
		}
		
		for (my $index1=0; $index1< scalar(@eigenValMatrix) ;$index1++){
			for (my $index2=0; $index2< $index1 ;$index2++){
				$G[$index1][$index2]=0;
				$G[$index2][$index1]=0;
			}
			$G[$index1][$index1]=0;
		}
		
		return \@G;
	}
}


no Moose;
__PACKAGE__->meta->make_immutable;
