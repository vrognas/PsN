#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use File::Copy qw(cp);
use FindBin qw($Bin);
use lib "$Bin/../.."; #location of includes.pm
use includes; #file with paths to PsN packages

use tool::bootstrap;
use model;

our $test_files = $includes::testfiledir;
our $tempdir = create_test_dir("unit_bootstrap");

my $model = model->new(
    filename => "$test_files/pheno.mod",
    ignore_missing_files => 1,
    skip_data_parsing => 1,
    ignore_missing_data => 1,
);

my $bootstrap = tool::bootstrap->new(directory => $tempdir, skip_estimate_near_boundary => 1, models => [ $model ]);
cp("$test_files/bootstrap/raw_results_pheno.csv", "$tempdir/raw_results.csv");
cp("$test_files/bootstrap/raw_results_structure", $tempdir);

$bootstrap->prepare_results();

cmp_float_array($bootstrap->result_parameters->{'standard_errors'}[0][0], 
[          '50.2956802844971',
          '0.000434273655751734',
          '0.0805879120090967',
          '0.161403546814575',
          '0.0347725938882654',
          '0.00354685011784463',
          '0.000204702373358662',
          '0.0129693855699637',
          '0.0770197642009448',
          '0.00877106021033009',
          '0.000854664450256878',
          '0',
          '0',
          '0',
          '0.104814378949648',
          '0.127150226219515',
          '0.18728695414251',
          '0.195112088742588',
          '0.350730226161449' ], 
 "bootstrap SE");

cmp_float_array($bootstrap->result_parameters->{'means'}[0][0],
[
          '730.902946197108',
          '0.00563684035532995',
          '1.35622050761421',
          '0.237140052532995',
          '0.146171840101523',
          '0.0163695091878173',
          '0.00041359852284264',
          '0.0807385228426395',
          '0.12380654822335',
          '0.0363546182741117',
          '0.00340842791878173',
          0,
          0,
          0,
          '0.292248584263959',
          '0.496992284263959',
          '0.793996030456853',
          '1.33788835532995',
          '2.0788745177665'
        ], "bootstrap means");

cmp_float_array($bootstrap->result_parameters->{'medians'}[0][0],
[
          '726.695910906915',
          '0.00565429',
          '1.35331',
          '0.243549',
          '0.143187',
          '0.0160961',
          '0.000375761',
          '0.0806145',
          '0.152033',
          '0.0351743',
          '0.00329674',
          '0',
          '0',
          '0',
          '0.288063',
          '0.505534',
          '0.811818',
          '1.32975',
          '2.03628'
        ], "bootstrap medians");

cmp_float_matrix($bootstrap->result_parameters->{'percentile_confidence_intervals'}[0],
          [
            [
              undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef,
              undef, undef, undef, undef
            ],
            [
              undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef,
              undef, undef, undef, undef
            ],
            [
              '631.444376434298',
              '0.0047221085',
              '1.199034',
              '0.01462384',
              '0.08671233',
              '0.0091890715',
              '0.00025935235',
              '0.05629991',
              '0.01547915',
              '0.022013255',
              '0.002191223',
              '0',
              '0',
              '0',
              '0.11576535',
              '0.2519392',
              '0.3693636',
              '0.8787687',
              '1.543666'
            ],
            [
              '654.061413002186',
              '0.004825269',
              '1.227445',
              '0.02941278',
              '0.0924221',
              '0.01076629',
              '0.0002744683',
              '0.05949504',
              '0.01689262',
              '0.02351979',
              '0.002352712',
              '0',
              '0',
              '0',
              '0.1347911',
              '0.2871907',
              '0.4335367',
              '1.02879',
              '1.627283'
            ],
            [
              '819.007477373408',
              '0.006296348',
              '1.485383',
              '0.5431352',
              '0.2087602',
              '0.02262412',
              '0.0006432313',
              '0.1005279',
              '0.2281467',
              '0.05179508',
              '0.004996734',
              0,
              0,
              0,
              '0.4655304',
              '0.7121154',
              '1.07125',
              '1.660071',
              '2.654923'
            ],
            [
              '834.133107775581',
              '0.006413703',
              '1.5299115',
              '0.64512755',
              '0.2168945',
              '0.023751545',
              '0.0008738686',
              '0.1064845',
              '0.2465499',
              '0.056997505',
              '0.0059436135',
              0,
              0,
              0,
              '0.504085',
              '0.7648396',
              '1.109556',
              '1.711025',
              '3.3279905'
            ],
            [
              undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef,
              undef, undef, undef
            ],
            [
              undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef,
              undef, undef, undef
            ]
          ], "bootstrap percentile confidence intervals");


cmp_float_array($bootstrap->result_parameters->{'bias'}[0][0],
[
              '-11.1480988723555',
              '8.32103553299471e-05',
              '0.0198405076142132',
              '-0.00993394746700524',
              '0.00459084010152278',
              '-4.57908121827416e-05',
              '1.88355228426395e-05',
              '0.000836722842639553',
              '-0.0317234517766498',
              '0.00146051827411168',
              '1.37679187817256e-05',
              '0',
              '0',
              '0',
              '-0.176389415736041',
              '-0.0841857157360409',
              '-0.181597969543147',
              '0.18839835532995',
              '0.253774517766497'
], "bootstrap bias");


cmp_float_matrix($bootstrap->result_parameters->{'standard_error_confidence_intervals'}[0],
          [
            [
              '576.553109093325',
              '0.00412465253574892',
              '1.07120547553407',
              '-0.284024370793359',
              '0.0271617798106628',
              '0.00474438968723226',
              '-0.000278810159536677',
              '0.0372260367820343',
              '-0.097903534103209',
              '0.00603292637790883',
              '0.000582386626429744',
              '0',
              '0',
              '0',
              '0.123746286066183',
              '0.162790180624685',
              '0.359326277394071',
              '0.507473671992514',
              '0.671022190815752'
            ],
            [
              '612.499431792655',
              '0.00443502791751469',
              '1.12880165624697',
              '-0.168669255884983',
              '0.052013752662606',
              '0.00727932346645581',
              '-0.000132509373297242',
              '0.0464952566488874',
              '-0.0428575086287937',
              '0.0123016031102317',
              '0.00119321530902833',
              '0',
              '0',
              '0',
              '0.198657122701497',
              '0.253664447303773',
              '0.493180263519722',
              '0.646920281816842',
              '0.92168908345334'
            ],
            [
              '643.471511711849',
              '0.0047024536347266',
              '1.17842769246217',
              '-0.0692769517565672',
              '0.0734267159789999',
              '0.00946347376902453',
              '-6.45365178297759e-06',
              '0.0544818042828711',
              '0.00457126216614812',
              '0.017702821987753',
              '0.00171951767749652',
              '0',
              '0',
              '0',
              '0.26320181725869',
              '0.33196355660975',
              '0.60851156988068',
              '0.767070306064528',
              '1.13766875672356'
            ],
            [
              '659.319680569494',
              '0.00483929326365397',
              '1.20382094353624',
              '-0.0184186941552946',
              '0.0843835603131923',
              '0.0105810862411574',
              '5.80480660623368e-05',
              '0.0585684576759666',
              '0.0288401898658658',
              '0.020466583060028',
              '0.00198882244577246',
              '0',
              '0',
              '0',
              '0.296228828065724',
              '0.372028592891519',
              '0.667525689130985',
              '0.828550125227317',
              '1.24818385098703'
            ],
            [
              '824.782409569432',
              '0.00626796673634603',
              '1.46893905646376',
              '0.512566694155295',
              '0.198778439686808',
              '0.0222495137588426',
              '0.000731477933937663',
              '0.101235142324033',
              '0.282219810134134',
              '0.049321616939972',
              '0.00480049755422754',
              '0',
              '0',
              '0',
              '0.641047171934276',
              '0.79032740710848',
              '1.28366231086901',
              '1.47042987477268',
              '2.40201614901297'
            ],
            [
              '840.630578427077',
              '0.0064048063652734',
              '1.49433230753783',
              '0.563424951756567',
              '0.209735284021',
              '0.0233671262309755',
              '0.000795979651782978',
              '0.105321795717129',
              '0.306488737833852',
              '0.052085378012247',
              '0.00506980232250348',
              '0',
              '0',
              '0',
              '0.67407418274131',
              '0.83039244339025',
              '1.34267643011932',
              '1.53190969393547',
              '2.51253124327644'
            ],
            [
              '871.602658346271',
              '0.00667223208248532',
              '1.54395834375303',
              '0.662817255884983',
              '0.231148247337394',
              '0.0255512765335442',
              '0.000922035373297242',
              '0.113308343351113',
              '0.353917508628794',
              '0.0574865968897682',
              '0.00559610469097167',
              '0',
              '0',
              '0',
              '0.738618877298503',
              '0.908691552696227',
              '1.45800773648028',
              '1.65205971818316',
              '2.72851091654666'
            ],
            [
              '907.548981045601',
              '0.00698260746425108',
              '1.60155452446593',
              '0.778172370793359',
              '0.256000220189337',
              '0.0280862103127677',
              '0.00106833615953668',
              '0.122577563217966',
              '0.408963534103209',
              '0.0637552736220912',
              '0.00620693337357026',
              '0',
              '0',
              '0',
              '0.813529713933817',
              '0.999565819375315',
              '1.59186172260593',
              '1.79150632800749',
              '2.97917780918425'
            ]
          ], "bootstrap standard.error.confidence.intervals");

#use Data::Dumper;
#print Dumper($bootstrap->result_parameters->{'standard_error_confidence_intervals'});

remove_test_dir($tempdir);

done_testing();
