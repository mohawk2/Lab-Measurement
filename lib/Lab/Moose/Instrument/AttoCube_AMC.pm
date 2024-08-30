package Lab::Moose::Instrument::AttoCube_AMC;
  
use 5.020;

use Moose;
use time::HiRes qw/time/;
use MooseX::Params::Validate;
use Lab::Moose::Instrument qw/validated_getter validated_setter/;
#use Lab::Moose::Instrument::Cache;
use Carp;
use namespace::autoclean;

use JSON::PP;
use Tie::IxHash;
 
# (1)
extends 'Lab::Moose::Instrument';

has 'request_id' => ( 
	is => 'rw', 
	isa => 'Int', 
	default => int(rand(100000))
);
has 'api_version' => ( 
	is => 'ro', 
	isa => 'Int', 
	default => 2
);
has 'language' => ( 
	is => 'ro', 
	isa => 'Int', 
	default => 0
);
has 'json' => (
	is => 'ro',
	isa => 'JSON::PP',
	default => sub { JSON::PP->new },
);
has 'response_qeue' => (
  is => 'rw',
  isa => 'HashRef',
  default => sub { {} },
)

=head1 AttoCube AMC300

here a very nice documentation will follow soon

=cut

# This is manually written:
 
# (3)
sub BUILD {
  my $self = shift;
  $self->clear();
  # $self->cls();
}
 
sub _send_command {
  my ($self, $method, $params, %args) = validated_list (
    \@_,
    method => { isa => 'Str' },
    params => { isa => 'ArrayRef' },
  );
  # TODO: list the arbitrary array %args really needed? check that!
  # Further check which type the content of params should have?

  # for checking, TODO: remove later
  print("This is method: $method, and this param: $params\n");

  # Create the JSON-RPC request TODO: change to JSON::RPC2 if it complies?
  # my $request = {
  #   id      => $self->request_id(), # You can increment this ID if needed
  #   params  => $params || {},
  # 	api 	  => 2,
  #   method  => $method,
  #   jsonrpc => "2.0",
  # };

  # Try to create an orderd hash for the JSON-RPC request
  tie my %request, 'Tie::IxHash',
    jsonrpc => "2.0",
    method  => $method,
    api 	  => 2,
    params  => $params || {},
    id      => $self->request_id(); 

  # Encode the request to JSON
  my $json_request = $self->json->encode(\%request);

  # Send the JSON request over the TCP socket
  $self->write(command => $json_request);
  
  # increment request id and store old id to return
  my $old_id = $self->request_id;
  $self->request_id($self->request_id + 1);
  
  return $old_id;  
}

sub _receive_response {
  my ($self, $response_id) = validated_list(
    \@_,
    response_id => { isa => 'Int' },
  );

  my $start_time = time();
  while(true) {
    # Check if response is in queue
    if exists $self->response_qeue->{$response_id} {
      my $response = $self->response_qeue->{$response_id};
      delete $self->response_qeue->{$response_id};
      return $response;
    }

    if time() - start_time > 10 {
      croak "Received no response from server after 10 seconds";
    }

    # TODO: Add a lock check?
    # Receive the response from the server
    my $response = $self->read();

    # Decode the JSON response
    my $decoded_response = $self->json->decode($response);

    # check if response id matches request id 
    if ($self->request_id != $decoded_response->{id}) {
      # add response to queue
      $self->response_qeue->{$decoded_response->{id}} = $decoded_response;
    } else {
      return $decoded_response;
    }
  }
}

sub request {
  my ($self, $method, $params, %args) = validated_list (
    @_,
    method => { isa => 'Str' },
    params => { isa => 'ArrayRef' },
  );
  my $request_id = $self->_send_command($method, $params, %args);
  return $self->_receive_response($request_id);
}

sub handle_error {
  my ($self, $response) = validated_list(
    \@_,
    response => { isa => 'HashRef' },
  );
  # Check for JSON-RPC protocol errors
  if 'error' in $response {
    my $error = $response->{error};
    croak "JSON-RPC Error occured: $error->{message} ($error->{code})\n";
  }
  # Check for AttoCube errors
  my $errNo = $response->{result}[0];
  # TODO: add ignoreFunctionError here as well?
  if ($errNo != 0 and $errNo != 'null') {
    my $errStr = $self.errorNumberToString($self->language, $errNo);
    croak "AttoCube Error: $errNo\nError Text: $errStr\n";
  }
  return $errNo;
}

sub measure {
  my ($self) = @_;

  # Use the send_json_rpc_command method to request a measurement
  my $result = $self->_send_command(method => 'com.attocube.amc.control.setSensorEnabled', params => [0, 1]);
  $result = $self->_send_command(method => 'com.attocube.amc.move.getPosition', params => [0]);
  $result = $self->_send_command(method => 'com.attocube.amc.control.getSensorEnabled', params => [0]);

  if (defined $result) {
    return $result;
  } else {
    die "Measurement failed\n";
  }

}

=head2 Autogenerted code

The code below was automatically generated. Please use carfully!

=cut
 
=head2 getLockStatus
 Description:
		  This function returns if the device is locked and if the current client is authorized to use the device. 
 Arguments:
 Returns:
		errorCode 
		locked 
		Is the device locked? 
		authorized 
		Is the client authorized? 
		JSON Method 
		 
=cut
sub getLockStatus {
	my ($self) = shift

	my $response = $self->request(method => 'getLockStatus')

	self->handle_error($response)

	return response
}

=head2 grantAccess
 Description:
		  Grants access to a locked device for the requesting IP by checking against the password 
 Arguments:
		password 
		string the current password 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub grantAccess {
	my ($self, $password, %args) = validated_list(
		password	=> {isa => 'Str', optional => 0,},
	);

	my $response = $self->request(method => 'grantAccess', params => [$password])

	self->handle_error($response)

	return response
}

=head2 lock
 Description:
		  This function locks the device with a password, so the calling of functions is only possible with this password. The locking IP is automatically added to the devices which can access functions 
 Arguments:
		password 
		string the password to be set 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub lock {
	my ($self, $password, %args) = validated_list(
		password	=> {isa => 'Str', optional => 0,},
	);

	my $response = $self->request(method => 'lock', params => [$password])

	self->handle_error($response)

	return response
}

=head2 unlock
 Description:
		  This function unlocks the device, so it will not be necessary to execute the grantAccess function to run any function 
 Arguments:
		password 
		string the current password 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub unlock {
	my ($self, $password, %args) = validated_list(
		password	=> {isa => 'Str', optional => 0,},
	);

	my $response = $self->request(method => 'unlock', params => [$password])

	self->handle_error($response)

	return response
}

=head2 getLowerSoftLimit
 Description:
		  Gets the lower boundary of the soft limit protection. This protection is needed if the IDS working range is smaller than the positioners travel range. It is no hard limit, so, it is possible to overshoot it! 
 Arguments:
		axis 
		Axis of the AMC to get the soft limit status from 
 Returns:
		int32 
		Error number if one occured, 0 in case of no error 
		limit 
		double 
		Lower boundary in pm 
		JSON Method 
		 
=cut
sub getLowerSoftLimit {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.amcids.getLowerSoftLimit', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getSoftLimitEnabled
 Description:
		  Gets whether the soft limit protection is enabled. This protection is needed if the IDS working range is smaller than the positioners travel range. It is no hard limit, so, it is possible to overshoot it! 
 Arguments:
		axis 
		Axis of the AMC to get the soft limit status from 
 Returns:
		int32 
		Error number if one occured, 0 in case of no error 
		enabled 
		boolean 
		True, if the soft limit should be enabled on this axis 
		JSON Method 
		 
=cut
sub getSoftLimitEnabled {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.amcids.getSoftLimitEnabled', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getSoftLimitReached
 Description:
		  Gets whether the current position is out of the soft limit boundaries. This protection is needed if the IDS working range is smaller than the positioners travel range. It is no hard limit, so, it is possible to overshoot it! 
 Arguments:
		axis 
		Axis of the AMC to get the soft limit status from 
 Returns:
		int32 
		Error number if one occured, 0 in case of no error 
		enabled 
		boolean 
		True, if the position is not within the boundaries 
		JSON Method 
		 
=cut
sub getSoftLimitReached {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.amcids.getSoftLimitReached', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getUpperSoftLimit
 Description:
		  Gets the upper lower boundary of the soft limit protection. This protection is needed if the IDS working range is smaller than the positioners travel range. It is no hard limit, so, it is possible to overshoot it! 
 Arguments:
		axis 
		Axis of the AMC to get the soft limit status from 
 Returns:
		int32 
		Error number if one occured, 0 in case of no error 
		limit 
		double 
		Upper boundary in pm 
		JSON Method 
		 
=cut
sub getUpperSoftLimit {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.amcids.getUpperSoftLimit', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 resetIdsAxis
 Description:
		  Resets the position value to zero of a specific measurement axis. Use this for positioners with an IDS as sensor. This method does not work for NUM and RES sensors. Use com.attocube.amc.control.resetAxis instead. 
 Arguments:
		axis 
		Axis of the IDS to reset the position 
 Returns:
		int32 
		Error number if one occured, 0 in case of no error 
		JSON Method 
		 
=cut
sub resetIdsAxis {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.amcids.resetIdsAxis', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 setLowerSoftLimit
 Description:
		  Sets the lower boundary of the soft limit protection in pm. This protection is needed if the IDS working range is smaller than the positioners travel range. It is no hard limit, so, it is possible to overshoot it! 
 Arguments:
		axis 
		Axis of the AMC where the soft limit should be changed 
		limit 
		Lower boundary in pm 
 Returns:
		int32 
		Error number if one occured, 0 in case of no error 
		JSON Method 
		 
=cut
sub setLowerSoftLimit {
	my ($self, $axis, $limit, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		limit	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.amcids.setLowerSoftLimit', params => [$axis, $limit])

	self->handle_error($response)

	return response
}

=head2 setSoftLimitEnabled
 Description:
		  Enables/disables the soft limit protection. This protection is needed if the IDS working range is smaller than the positioners travel range. It is no hard limit, so, it is possible to overshoot it! 
 Arguments:
		axis 
		Axis of the AMC where the soft limit should be changed 
		enabled 
		True, if the soft limit should be enabled on this axis 
 Returns:
		int32 
		Error number if one occured, 0 in case of no error 
		JSON Method 
		 
=cut
sub setSoftLimitEnabled {
	my ($self, $axis, $enabled, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enabled	=> {isa => 'Bool', optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.amcids.setSoftLimitEnabled', params => [$axis, $enabled])

	self->handle_error($response)

	return response
}

=head2 setUpperSoftLimit
 Description:
		  Sets the upper boundary of the soft limit protection in pm. This protection is needed if the IDS working range is smaller than the positioners travel range. It is no hard limit, so, it is possible to overshoot it! 
 Arguments:
		axis 
		Axis of the AMC where the soft limit should be changed 
		limit 
		Upper boundary in pm 
 Returns:
		int32 
		Error number if one occured, 0 in case of no error 
		JSON Method 
		 
=cut
sub setUpperSoftLimit {
	my ($self, $axis, $limit, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		limit	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.amcids.setUpperSoftLimit', params => [$axis, $limit])

	self->handle_error($response)

	return response
}

=head2 MultiAxisPositioning
 Description:
		  Simultaneously set 3 axes positions and get positions to minimize network latency 
 Arguments:
		set1 
		axis1 otherwise pos1 target is ignored 
		set2 
		axis2 otherwise pos2 target is ignored 
		set3 
		axis3 otherwise pos3 target is ignored 
		target1 
		target position of axis 1 
		target2 
		target position of axis 2 
		target3 
		target position of axis 3 
 Returns:
		ref1 
		Status of axis 1 
		ref2 
		Status of axis 2 
		ref3 
		Status of axis 3 
		refpos1 
		reference Position of axis 1 
		refpos2 
		reference Position of axis 2 
		refpos3 
		reference Position of axis 3 
		pos1 
		position of axis 1 
		pos2 
		position of axis 2 
		pos3 
		position of axis 3 
		JSON Method 
		 
=cut
sub MultiAxisPositioning {
	my ($self, $set1, $set2, $set3, $target1, $target2, $target3, %args) = validated_list(
		set1	=> {, optional => 0,},
		set2	=> {, optional => 0,},
		set3	=> {, optional => 0,},
		target1	=> {, optional => 0,},
		target2	=> {, optional => 0,},
		target3	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.MultiAxisPositioning', params => [$set1, $set2, $set3, $target1, $target2, $target3])

	self->handle_error($response)

	return response
}

=head2 getActorName
 Description:
		  This function gets the name of the positioner of the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		actor_name 
		actor_name 
		JSON Method 
		 
=cut
sub getActorName {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getActorName', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getActorParametersActorName
 Description:
		  Control the actors parameter: actor name 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		actorname 
		actorname 
		JSON Method 
		 
=cut
sub getActorParametersActorName {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getActorParametersActorName', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getActorSensitivity
 Description:
		  Get the setting for the actor parameter sensitivity 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		sensitivity 
		sensitivity 
		JSON Method 
		 
=cut
sub getActorSensitivity {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getActorSensitivity', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getActorType
 Description:
		  This function gets the type of the positioner of the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		actor_type 
		0: linear, 1: rotator, 2: goniometer 
		JSON Method 
		 
=cut
sub getActorType {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getActorType', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getAutoMeasure
 Description:
		  This function returns if the automeasurement on axis enable is enabled 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		enable 
		true: enable automeasurement, false: disable automeasurement 
		JSON Method 
		 
=cut
sub getAutoMeasure {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getAutoMeasure', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlAmplitude
 Description:
		  This function gets the amplitude of the actuator signal of the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		amplitude 
		in mV 
		JSON Method 
		 
=cut
sub getControlAmplitude {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getControlAmplitude', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlAutoReset
 Description:
		  This function resets the position every time the reference position is detected. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		enabled 
		boolean 
		JSON Method 
		 
=cut
sub getControlAutoReset {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getControlAutoReset', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlFixOutputVoltage
 Description:
		  This function gets the DC level output of the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		amplitude_mv 
		in mV 
		JSON Method 
		 
=cut
sub getControlFixOutputVoltage {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getControlFixOutputVoltage', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlFrequency
 Description:
		  This function gets the frequency of the actuator signal of the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		frequency 
		in mHz 
		JSON Method 
		 
=cut
sub getControlFrequency {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getControlFrequency', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlMove
 Description:
		  This function gets the approach of the selected axis’ positioner to the target position. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		enable 
		boolean true: closed loop control enabled, false: closed loop control 
		disabled 
		JSON Method 
		 
=cut
sub getControlMove {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getControlMove', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlOutput
 Description:
		  This function gets the status of the output relays of the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		enabled 
		power status (true = enabled,false = disabled) 
		JSON Method 
		 
=cut
sub getControlOutput {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getControlOutput', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlReferenceAutoUpdate
 Description:
		  This function gets the status of whether the reference position is updated when the reference mark is hit. When this function is disabled, the reference marking will be considered only the first time and after then ignored. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		enabled 
		boolen 
		JSON Method 
		 
=cut
sub getControlReferenceAutoUpdate {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getControlReferenceAutoUpdate', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlTargetRange
 Description:
		  This function gets the range around the target position in which the flag "In Target Range" becomes active. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		targetrange 
		in nm 
		JSON Method 
		 
=cut
sub getControlTargetRange {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getControlTargetRange', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getCrosstalkThreshold
 Description:
		  This function gets the threshold range and slip phase time which is used while moving another axis 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		range 
		in pm 
		time 
		after slip phase which is waited until the controller is acting again in 
		microseconds 
		JSON Method 
		 
=cut
sub getCrosstalkThreshold {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getCrosstalkThreshold', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getCurrentOutputVoltage
 Description:
		  This function gets the current Voltage which is applied to the Piezo 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		amplitude 
		in mV 
		JSON Method 
		 
=cut
sub getCurrentOutputVoltage {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getCurrentOutputVoltage', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getExternalSensor
 Description:
		  This function gets whether the sensor source of closed loop is IDS It is only available when the feature AMC/IDS closed loop has been activated 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		enabled 
		enabled 
		JSON Method 
		 
=cut
sub getExternalSensor {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getExternalSensor', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getFinePositioningRange
 Description:
		  This function gets the fine positioning DC-range 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		range 
		in nm 
		JSON Method 
		 
=cut
sub getFinePositioningRange {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getFinePositioningRange', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getFinePositioningSlewRate
 Description:
		  This function gets the fine positioning slew rate 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		slewrate 
		[0|1|2|3] 
		JSON Method 
		 
=cut
sub getFinePositioningSlewRate {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getFinePositioningSlewRate', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getMotionControlThreshold
 Description:
		  This function gets the threshold range within the closed-loop controlled movement stops to regulate. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		threshold 
		in pm 
		JSON Method 
		 
=cut
sub getMotionControlThreshold {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getMotionControlThreshold', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getPositionsAndVoltages
 Description:
		  Simultaneously get 3 axes positions as well as the DC offset to maximize sampling rate over network 
 Arguments:
 Returns:
		pos1 
		position of axis 1 
		pos2 
		position of axis 2 
		pos3 
		position of axis 3 
		val1 
		dc voltage of of axis 1 in mV 
		val2 
		dc voltage of of axis 2 in mV 
		val3 
		dc voltage of of axis 3 in mV 
		JSON Method 
		 
=cut
sub getPositionsAndVoltages {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.control.getPositionsAndVoltages')

	self->handle_error($response)

	return response
}

=head2 getReferencePosition
 Description:
		  This function gets the reference position of the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		position 
		position: For linear type actors the position is defined in nm for 
		goniometer an rotator type actors it is µ°. 
		JSON Method 
		 
=cut
sub getReferencePosition {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getReferencePosition', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getSensorDirection
 Description:
		  This function gets whether the IDS sensor source of closed loop is inverted It is only available when the feature AMC/IDS closed loop has been activated 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		inverted 
		boolen 
		JSON Method 
		 
=cut
sub getSensorDirection {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getSensorDirection', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getSensorEnabled
 Description:
		  Get sensot power supply status 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		value 
		true if enabled, false otherwise 
		JSON Method 
		 
=cut
sub getSensorEnabled {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.getSensorEnabled', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getStatusMovingAllAxes
 Description:
		  Get Status of all axes, see getStatusMoving for coding of the values 
 Arguments:
 Returns:
		moving1 
		status of axis 1 
		moving2 
		status of axis 2 
		moving3 
		status of axis 3 
		JSON Method 
		 
=cut
sub getStatusMovingAllAxes {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.control.getStatusMovingAllAxes')

	self->handle_error($response)

	return response
}

=head2 searchReferencePosition
 Description:
		  This function searches for the reference position of the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		JSON Method 
		 
=cut
sub searchReferencePosition {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.searchReferencePosition', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 setActorParametersByName
 Description:
		  This function sets the name for the positioner on the selected axis. The possible names can be retrieved by executing getPositionersList 
 Arguments:
		axis 
		[0|1|2] 
		actorname 
		name of the actor 
 Returns:
		JSON Method 
		 
=cut
sub setActorParametersByName {
	my ($self, $axis, $actorname, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		actorname	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setActorParametersByName', params => [$axis, $actorname])

	self->handle_error($response)

	return response
}

=head2 setActorParametersJson
 Description:
		  Select and override a positioner out of the Current default list only override given parameters set others default 
 Arguments:
		axis 
		[0|1|2] 
		json_dict 
		dict with override params 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setActorParametersJson {
	my ($self, $axis, $json_dict, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		json_dict	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setActorParametersJson', params => [$axis, $json_dict])

	self->handle_error($response)

	return response
}

=head2 setActorSensitivity
 Description:
		  Control the actor parameter closed loop sensitivity 
 Arguments:
		axis 
		[0|1|2] 
		sensitivity 
		 
 Returns:
		JSON Method 
		 
=cut
sub setActorSensitivity {
	my ($self, $axis, $sensitivity, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		sensitivity	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setActorSensitivity', params => [$axis, $sensitivity])

	self->handle_error($response)

	return response
}

=head2 setAutoMeasure
 Description:
		  This function enables/disables the automatic C/R measurement on axis enable 
 Arguments:
		axis 
		[0|1|2] 
		enable 
		true: enable automeasurement, false: disable automeasurement 
 Returns:
		JSON Method 
		 
=cut
sub setAutoMeasure {
	my ($self, $axis, $enable, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enable	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setAutoMeasure', params => [$axis, $enable])

	self->handle_error($response)

	return response
}

=head2 setControlAmplitude
 Description:
		  This function sets the amplitude of the actuator signal of the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
		amplitude 
		in mV 
 Returns:
		JSON Method 
		 
=cut
sub setControlAmplitude {
	my ($self, $axis, $amplitude, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		amplitude	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setControlAmplitude', params => [$axis, $amplitude])

	self->handle_error($response)

	return response
}

=head2 setControlAutoReset
 Description:
		  This function resets the position every time the reference position is detected. 
 Arguments:
		axis 
		[0|1|2] 
		enable 
		boolean 
 Returns:
		JSON Method 
		 
=cut
sub setControlAutoReset {
	my ($self, $axis, $enable, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enable	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setControlAutoReset', params => [$axis, $enable])

	self->handle_error($response)

	return response
}

=head2 setControlFixOutputVoltage
 Description:
		  This function sets the DC level output of the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
		amplitude_mv 
		in mV 
 Returns:
		JSON Method 
		 
=cut
sub setControlFixOutputVoltage {
	my ($self, $axis, $amplitude_mv, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		amplitude_mv	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setControlFixOutputVoltage', params => [$axis, $amplitude_mv])

	self->handle_error($response)

	return response
}

=head2 setControlFrequency
 Description:
		  This function sets the frequency of the actuator signal of the selected axis. Note: Approximate the slewrate of the motion controller  according to Input Frequency 
 Arguments:
		axis 
		[0|1|2] 
		frequency 
		in  mHz 
 Returns:
		JSON Method 
		 
=cut
sub setControlFrequency {
	my ($self, $axis, $frequency, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		frequency	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setControlFrequency', params => [$axis, $frequency])

	self->handle_error($response)

	return response
}

=head2 setControlMove
 Description:
		  This function sets the approach of the selected axis’ positioner to the target position. 
 Arguments:
		axis 
		[0|1|2] 
		enable 
		boolean true: eanble the approach , false: disable the approach 
 Returns:
		JSON Method 
		 
=cut
sub setControlMove {
	my ($self, $axis, $enable, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enable	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setControlMove', params => [$axis, $enable])

	self->handle_error($response)

	return response
}

=head2 setControlOutput
 Description:
		  This function sets the status of the output relays of the selected axis. Enable only if cable is connected and FlyBack is enabled use a PWM startup of 1sec 
 Arguments:
		axis 
		[0|1|2] 
		enable 
		true: enable drives, false: disable drives 
 Returns:
		JSON Method 
		 
=cut
sub setControlOutput {
	my ($self, $axis, $enable, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enable	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setControlOutput', params => [$axis, $enable])

	self->handle_error($response)

	return response
}

=head2 setControlReferenceAutoUpdate
 Description:
		  This function sets the status of whether the reference position is updated when the reference mark is hit. When this function is disabled, the reference marking will be considered only the first time and after then ignored. 
 Arguments:
		axis 
		[0|1|2] 
		enable 
		boolean 
 Returns:
		JSON Method 
		 
=cut
sub setControlReferenceAutoUpdate {
	my ($self, $axis, $enable, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enable	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setControlReferenceAutoUpdate', params => [$axis, $enable])

	self->handle_error($response)

	return response
}

=head2 setControlTargetRange
 Description:
		  This function sets the range around the target position in which the flag "In Target Range" (see VIII.7.a) becomes active. 
 Arguments:
		axis 
		[0|1|2] 
		range 
		in nm 
 Returns:
		JSON Method 
		 
=cut
sub setControlTargetRange {
	my ($self, $axis, $range, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		range	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setControlTargetRange', params => [$axis, $range])

	self->handle_error($response)

	return response
}

=head2 setCrosstalkThreshold
 Description:
		  This function sets the threshold range and slip phase time which is used while moving another axis 
 Arguments:
		axis 
		[0|1|2] 
		threshold 
		in pm 
		slipphasetime 
		time after slip phase which is waited until the controller is acting 
		again in microseconds 
 Returns:
		JSON Method 
		 
=cut
sub setCrosstalkThreshold {
	my ($self, $axis, $threshold, $slipphasetime, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		threshold	=> {, optional => 0,},
		slipphasetime	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setCrosstalkThreshold', params => [$axis, $threshold, $slipphasetime])

	self->handle_error($response)

	return response
}

=head2 setExternalSensor
 Description:
		  This function sets the sensor source of closed loop to the IDS when enabled. Otherwise the normal AMC Sensor depending on the configuration (e.g. NUM or RES) is used It is only available when the feature AMC/IDS closed loop has been activated 
 Arguments:
		axis 
		[0|1|2] 
		enabled 
		 
 Returns:
		warningNo 
		Warning code, can be converted into a string using the 
		errorNumberToString function 
		JSON Method 
		 
=cut
sub setExternalSensor {
	my ($self, $axis, $enabled, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enabled	=> {isa => 'Bool', optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setExternalSensor', params => [$axis, $enabled])

	self->handle_error($response)

	return response
}

=head2 setFinePositioningRange
 Description:
		  This function sets the fine positioning DC-range 
 Arguments:
		axis 
		[0|1|2] 
		range 
		in nm 
 Returns:
		JSON Method 
		 
=cut
sub setFinePositioningRange {
	my ($self, $axis, $range, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		range	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setFinePositioningRange', params => [$axis, $range])

	self->handle_error($response)

	return response
}

=head2 setFinePositioningSlewRate
 Description:
		  This function sets the fine positioning slew rate 
 Arguments:
		axis 
		[0|1|2] 
		slewrate 
		[0|1|2|3] 
 Returns:
		JSON Method 
		 
=cut
sub setFinePositioningSlewRate {
	my ($self, $axis, $slewrate, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		slewrate	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setFinePositioningSlewRate', params => [$axis, $slewrate])

	self->handle_error($response)

	return response
}

=head2 setMotionControlThreshold
 Description:
		  This function sets the threshold range within the closed-loop controlled movement stops to regulate. Default depends on connected sensor type 
 Arguments:
		axis 
		[0|1|2] 
		threshold 
		in pm 
 Returns:
		JSON Method 
		 
=cut
sub setMotionControlThreshold {
	my ($self, $axis, $threshold, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		threshold	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setMotionControlThreshold', params => [$axis, $threshold])

	self->handle_error($response)

	return response
}

=head2 setReset
 Description:
		  This function resets the actual position of the selected axis given by the NUM sensor to zero and marks the reference position as invalid. It does not work for RES positioners and positions read by IDS. For IDS, use com.attocube.ids.displacement.resetAxis() or com.attocube.amc.amcids.resetIdsAxis() instead. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		JSON Method 
		 
=cut
sub setReset {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setReset', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 setSensorDirection
 Description:
		  This function sets the IDS sensor source of closed loop to inverted when true. It is only available when the feature AMC/IDS closed loop has been activated 
 Arguments:
		axis 
		[0|1|2] 
		inverted 
		 
 Returns:
		JSON Method 
		 
=cut
sub setSensorDirection {
	my ($self, $axis, $inverted, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		inverted	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setSensorDirection', params => [$axis, $inverted])

	self->handle_error($response)

	return response
}

=head2 setSensorEnabled
 Description:
		  Set sensor power supply status, can be switched off to save heat generated by sensor [NUM or RES] Positions retrieved will be invalid when activating this, so closed-loop control should be switched off beforehand 
 Arguments:
		axis 
		[0|1|2] 
		value 
		true if enabled, false otherwise 
 Returns:
		JSON Method 
		 
=cut
sub setSensorEnabled {
	my ($self, $axis, $value, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		value	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.control.setSensorEnabled', params => [$axis, $value])

	self->handle_error($response)

	return response
}

=head2 checkChassisNbr
 Description:
		  Get Chassis and Slot Number, only works when AMC is within a Rack 
 Arguments:
 Returns:
		errorCode 
		slotNbr 
		slotNbr 
		chassisNbr 
		chassisNbr 
		JSON Method 
		 
=cut
sub checkChassisNbr {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.description.checkChassisNbr')

	self->handle_error($response)

	return response
}

=head2 getDeviceType
 Description:
		  This function gets the device type based on its EEPROM configuration. 
 Arguments:
 Returns:
		devicetype 
		Device name (AMC100, AMC150, AMC300) with attached feature 
		( AMC100\\NUM, AMC100\\NUM\\PRO) 
		JSON Method 
		 
=cut
sub getDeviceType {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.description.getDeviceType')

	self->handle_error($response)

	return response
}

=head2 getFeaturesActivated
 Description:
		  Get the activated features and return as a string 
 Arguments:
 Returns:
		features 
		activated on device concatenated by comma e.g. Closed loop 
		Operation, Pro, Wireless Controller, IO 
		JSON Method 
		 
=cut
sub getFeaturesActivated {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.description.getFeaturesActivated')

	self->handle_error($response)

	return response
}

=head2 getPositionersList
 Description:
		  This function reads the actor names that can be connected to the device. 
 Arguments:
 Returns:
		PositionersList 
		PositionersList 
		JSON Method 
		 
=cut
sub getPositionersList {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.description.getPositionersList')

	self->handle_error($response)

	return response
}

=head2 getDiagnosticPower
 Description:
		  Returns the current power consumption 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		power 
		power 
		JSON Method 
		 
=cut
sub getDiagnosticPower {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.diagnostic.getDiagnosticPower', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getDiagnosticResults
 Description:
		  Returns the results of the last diagnostic run and an error, if there was no run, it is currently running or the run failed 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		capacity 
		in nF 
		resistance 
		in Ohm 
		JSON Method 
		 
=cut
sub getDiagnosticResults {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.diagnostic.getDiagnosticResults', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getDiagnosticStepSize
 Description:
		  Performs 10 steps in forward and backward and calculates the average step size in both directions on a specific axis 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		stepsize_fwd 
		stepsize_fwd 
		stepsize_bwd 
		stepsize_bwd 
		JSON Method 
		 
=cut
sub getDiagnosticStepSize {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.diagnostic.getDiagnosticStepSize', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getDiagnosticTemperature
 Description:
		  Returns the current axis temperature 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		temperature 
		temperature 
		JSON Method 
		 
=cut
sub getDiagnosticTemperature {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.diagnostic.getDiagnosticTemperature', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 startDiagnostic
 Description:
		  Start the diagnosis procedure for the given axis 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		JSON Method 
		 
=cut
sub startDiagnostic {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.diagnostic.startDiagnostic', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlContinuousBkwd
 Description:
		  This function gets the axis’ movement status in backward direction. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		enabled 
		true if movement backward is active , false otherwise 
		JSON Method 
		 
=cut
sub getControlContinuousBkwd {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.getControlContinuousBkwd', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlContinuousFwd
 Description:
		  This function gets the axis’ movement status in positive direction. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		enabled 
		true if movement Fwd is active, false otherwise 
		JSON Method 
		 
=cut
sub getControlContinuousFwd {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.getControlContinuousFwd', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlEotOutputDeactive
 Description:
		  This function gets the output applied to the selected axis on the end of travel. /PRO feature. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		enabled 
		If true, the output of the axis will be deactivated on positive EOT 
		detection. 
		JSON Method 
		 
=cut
sub getControlEotOutputDeactive {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.getControlEotOutputDeactive', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlTargetPosition
 Description:
		  This function gets the target position for the movement on the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		position 
		defined in nm for goniometer an rotator type actors it is µ°. 
		JSON Method 
		 
=cut
sub getControlTargetPosition {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.getControlTargetPosition', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getGroundAxis
 Description:
		  Checks if the axis piezo drive is actively grounded only in AMC300 
 Arguments:
		axis 
		montion controler axis [0|1|2] 
 Returns:
		0 or error 
		grounded 
		true or false 
		JSON Method 
		 
=cut
sub getGroundAxis {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.getGroundAxis', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getGroundAxisAutoOnTarget
 Description:
		  Pull axis piezo drive to GND if positioner is in ground target range only in AMC300 
 Arguments:
		axis 
		montion controler axis [0|1|2] 
 Returns:
		0 or error 
		value 
		true or false 
		JSON Method 
		 
=cut
sub getGroundAxisAutoOnTarget {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.getGroundAxisAutoOnTarget', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getGroundTargetRange
 Description:
		  Retrieves the range around the target position in which the auto grounding becomes active. only in AMC300 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		targetrange 
		in nm 
		JSON Method 
		 
=cut
sub getGroundTargetRange {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.getGroundTargetRange', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getNSteps
 Description:
		  This function gets the number of Steps in desired direction. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		nbrstep 
		nbrstep 
		JSON Method 
		 
=cut
sub getNSteps {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.getNSteps', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getPosition
 Description:
		  This function gets the current position of the positioner on the selected axis. The axis on the web application are indexed from 1 to 3 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		position 
		defined in nm for goniometer an rotator type actors it is µ°. 
		JSON Method 
		 
=cut
sub getPosition {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.getPosition', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 moveReference
 Description:
		  This function starts an approach to the reference position. A running motion command is aborted; closed loop moving is switched on. Requires a valid reference position. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		JSON Method 
		 
=cut
sub moveReference {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.moveReference', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 performNSteps
 Description:
		  Perform the OL command for N steps 
 Arguments:
		axis 
		[0|1|2] 
		backward 
		Selects the desired direction. False triggers a forward step, true a 
		backward step 
 Returns:
		JSON Method 
		 
=cut
sub performNSteps {
	my ($self, $axis, $backward, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		backward	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.performNSteps', params => [$axis, $backward])

	self->handle_error($response)

	return response
}

=head2 setControlContinuousBkwd
 Description:
		  This function sets a continuous movement on the selected axis in backward direction. 
 Arguments:
		axis 
		[0|1|2] 
		enable 
		If enabled a present movement in the opposite direction is stopped. 
		The parameter "false" stops all movement of the axis regardless its 
		direction 
 Returns:
		JSON Method 
		 
=cut
sub setControlContinuousBkwd {
	my ($self, $axis, $enable, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enable	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.setControlContinuousBkwd', params => [$axis, $enable])

	self->handle_error($response)

	return response
}

=head2 setControlContinuousFwd
 Description:
		  This function sets a continuous movement on the selected axis in positive direction. 
 Arguments:
		axis 
		[0|1|2] 
		enable 
		If enabled a present movement in the opposite direction is stopped. 
		The parameter "false" stops all movement of the axis regardless its 
		direction. 
 Returns:
		JSON Method 
		 
=cut
sub setControlContinuousFwd {
	my ($self, $axis, $enable, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enable	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.setControlContinuousFwd', params => [$axis, $enable])

	self->handle_error($response)

	return response
}

=head2 setControlEotOutputDeactive
 Description:
		  This function sets the output applied to the selected axis on the end of travel. 
 Arguments:
		axis 
		[0|1|2] 
		enable 
		if enabled, the output of the axis will be deactivated on positive 
		EOT detection. 
 Returns:
		JSON Method 
		 
=cut
sub setControlEotOutputDeactive {
	my ($self, $axis, $enable, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enable	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.setControlEotOutputDeactive', params => [$axis, $enable])

	self->handle_error($response)

	return response
}

=head2 setControlTargetPosition
 Description:
		  This function sets the target position for the movement on the selected axis. careful: the maximum positon in nm is 2**47/1000 
 Arguments:
		axis 
		[0|1|2] 
		target 
		absolute position : For linear type actors the position is defined in 
		nm for goniometer an rotator type actors it is µ°. 
 Returns:
		JSON Method 
		 
=cut
sub setControlTargetPosition {
	my ($self, $axis, $target, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		target	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.setControlTargetPosition', params => [$axis, $target])

	self->handle_error($response)

	return response
}

=head2 setGroundAxis
 Description:
		  Pull axis piezo drive to GND actively only in AMC300 this is used in MIC-Mode 
 Arguments:
		axis 
		motion controler axis [0|1|2] 
		enabled 
		true or false 
 Returns:
		0 or error 
		JSON Method 
		 
=cut
sub setGroundAxis {
	my ($self, $axis, $enabled, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enabled	=> {isa => 'Bool', optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.setGroundAxis', params => [$axis, $enabled])

	self->handle_error($response)

	return response
}

=head2 setGroundAxisAutoOnTarget
 Description:
		  Pull axis piezo drive to GND actively if positioner is in ground target range only in AMC300 this is used in MIC-Mode 
 Arguments:
		axis 
		montion controler axis [0|1|2] 
		enabled 
		true or false 
 Returns:
		0 or error 
		JSON Method 
		 
=cut
sub setGroundAxisAutoOnTarget {
	my ($self, $axis, $enabled, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enabled	=> {isa => 'Bool', optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.setGroundAxisAutoOnTarget', params => [$axis, $enabled])

	self->handle_error($response)

	return response
}

=head2 setGroundTargetRange
 Description:
		  Set  the range around the target position in which the auto grounding becomes active. only in AMC300 
 Arguments:
		axis 
		[0|1|2] 
		range 
		in nm 
 Returns:
		JSON Method 
		 
=cut
sub setGroundTargetRange {
	my ($self, $axis, $range, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		range	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.setGroundTargetRange', params => [$axis, $range])

	self->handle_error($response)

	return response
}

=head2 setNSteps
 Description:
		  This function triggers n steps on the selected axis in desired direction. /PRO feature. 
 Arguments:
		axis 
		[0|1|2] 
		backward 
		Selects the desired direction. False triggers a forward step, true a 
		backward step 
		step 
		number of step 
 Returns:
		JSON Method 
		 
=cut
sub setNSteps {
	my ($self, $axis, $backward, $step, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		backward	=> {, optional => 0,},
		step	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.setNSteps', params => [$axis, $backward, $step])

	self->handle_error($response)

	return response
}

=head2 setSingleStep
 Description:
		  This function triggers one step on the selected axis in desired direction. 
 Arguments:
		axis 
		[0|1|2] 
		backward 
		Selects the desired direction. False triggers a forward step, true a 
		backward step 
 Returns:
		JSON Method 
		 
=cut
sub setSingleStep {
	my ($self, $axis, $backward, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		backward	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.setSingleStep', params => [$axis, $backward])

	self->handle_error($response)

	return response
}

=head2 writeNSteps
 Description:
		  Sets the number of steps to perform on stepwise movement. /PRO feature. 
 Arguments:
		axis 
		[0|1|2] 
		step 
		number of step 
 Returns:
		JSON Method 
		 
=cut
sub writeNSteps {
	my ($self, $axis, $step, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		step	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.move.writeNSteps', params => [$axis, $step])

	self->handle_error($response)

	return response
}

=head2 getChainGain
 Description:
		  Get chain gain, see setChainGain for parameter description 
 Arguments:
		axis 
		number of axis 
 Returns:
		gaincoeff 
		gaincoeff 
		JSON Method 
		 
=cut
sub getChainGain {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.res.getChainGain', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getLinearization
 Description:
		  Gets wether linearization is enabled or not 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		enabled 
		true when enabled 
		JSON Method 
		 
=cut
sub getLinearization {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.res.getLinearization', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getLutSn
 Description:
		  get the identifier of the loaded lookuptable (will be empty if disabled) 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		value_string1 
		string : identifier 
		JSON Method 
		 
=cut
sub getLutSn {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.res.getLutSn', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getMode
 Description:
		  Get mode of RES application, see setMode for the description of possible parameters 
 Arguments:
 Returns:
		mode 
		mode 
		JSON Method 
		 
=cut
sub getMode {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.res.getMode')

	self->handle_error($response)

	return response
}

=head2 getSensorStatus
 Description:
		  Gets wether a valid RES position signal is present (always true for a disabled sensor and for rotators) 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		present 
		true when present 
		JSON Method 
		 
=cut
sub getSensorStatus {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.res.getSensorStatus', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 setChainGain
 Description:
		  Set signal chain gain to control overall power 
 Arguments:
		axis 
		number of axis 
		gainconfig 
		0: 0dB ( power 600mVpkpk^2/R), 1 : -10 dB , 2 : -15 dB , 3 : -20 
		dB 
 Returns:
		JSON Method 
		 
=cut
sub setChainGain {
	my ($self, $axis, $gainconfig, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		gainconfig	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.res.setChainGain', params => [$axis, $gainconfig])

	self->handle_error($response)

	return response
}

=head2 setConfigurationFile
 Description:
		  Load configuration file which either contains a JSON dict with parameters for the positioner on the axis or the LUT file itself (as legacy support for ANC350 .aps files) 
 Arguments:
		axis 
		[0|1|2] 
		content 
		JSON Dictionary or .aps File. 
		The JSON Dictonary can/must contain the following keys: 
		'type': mandatory This field has to be one of the positioner list (see 
		getPositionersList) 
		'lut': optional, contains an array of 1024 LUT values that are a 
		mapping between ratio of the RES element travelled (0 to 1) and the 
		corresponding absolute value at this ratio given in [nm]. 
		Note: when generating these tables with position data in absolute 
		units, the scaling of the travel ratio with the current sensor range has 
		to be reversed. 
		'lut_sn': optional, a string to uniquely identify the loaded LUT 
 Returns:
		JSON Method 
		 
=cut
sub setConfigurationFile {
	my ($self, $axis, $content, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		content	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.res.setConfigurationFile', params => [$axis, $content])

	self->handle_error($response)

	return response
}

=head2 setLinearization
 Description:
		  Control if linearization is enabled or not 
 Arguments:
		axis 
		[0|1|2] 
		enable 
		boolean ( true: enable linearization) 
 Returns:
		JSON Method 
		 
=cut
sub setLinearization {
	my ($self, $axis, $enable, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enable	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.res.setLinearization', params => [$axis, $enable])

	self->handle_error($response)

	return response
}

=head2 setMode
 Description:
		  Sets the mode of the RES position measurement This selects which frequency/ies are used for the lock-in measurement of the RES position, currently there are two possibilities: 1: Individual per axis: each axis is measured on a different frequency; this mode reduces noise coupling between axes, while requiring more wiring 2: Shared line/MIC-Mode: each axis is measured on the same frequency, which reduces the number of required wires while more coupling noise is excpected 
 Arguments:
		mode 
		1: Individual per axis 2: Shared line mode 
 Returns:
		JSON Method 
		 
=cut
sub setMode {
	my ($self, $mode, %args) = validated_list(
		mode	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.res.setMode', params => [$mode])

	self->handle_error($response)

	return response
}

=head2 getControlTargetRanges
 Description:
		  Checks if all three axis are in target range. 
 Arguments:
 Returns:
		int32 
		Error code, if there was an error, otherwise 0 for ok 
		in_target_range 
		boolean 
		true all three axes are in target range, false at least one axis is not 
		in target range 
		JSON Method 
		 
=cut
sub getControlTargetRanges {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.rotcomp.getControlTargetRanges')

	self->handle_error($response)

	return response
}

=head2 getEnabled
 Description:
		  Gets the enabled status of the rotation compensation 
 Arguments:
 Returns:
		int32 
		Error code, if there was an error, otherwise 0 for ok 
		enabled 
		boolean 
		true Rotation compensation is enabled, false Rotation compensation 
		is disabled 
		JSON Method 
		 
=cut
sub getEnabled {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.rotcomp.getEnabled')

	self->handle_error($response)

	return response
}

=head2 getLUT
 Description:
		  Gets the LUT file as JSON string 
 Arguments:
 Returns:
		int32 
		Error code, if there was an error, otherwise 0 for ok 
		lut 
		string 
		JSON string of the LUT file for the rotation compensation 
		JSON Method 
		 
=cut
sub getLUT {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.rotcomp.getLUT')

	self->handle_error($response)

	return response
}

=head2 setEnabled
 Description:
		  Enables and disables the rotation compensation 
 Arguments:
		enabled 
		true Rotation compensation is enabled, false Rotation compensation 
		is disabled 
 Returns:
		int32 
		Error code, if there was an error, otherwise 0 for ok 
		JSON Method 
		 
=cut
sub setEnabled {
	my ($self, $enabled, %args) = validated_list(
		enabled	=> {isa => 'Bool', optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rotcomp.setEnabled', params => [$enabled])

	self->handle_error($response)

	return response
}

=head2 setLUT
 Description:
		  Sets the LUT file from a JSON string 
 Arguments:
		lut_string 
		JSON string of the LUT file for the rotation compensation 
 Returns:
		int32 
		Error code, if there was an error, otherwise 0 for ok 
		JSON Method 
		 
=cut
sub setLUT {
	my ($self, $lut_string, %args) = validated_list(
		lut_string	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rotcomp.setLUT', params => [$lut_string])

	self->handle_error($response)

	return response
}

=head2 updateOffsets
 Description:
		  Updates the start offsets of the axes 
 Arguments:
		offset_axis0 
		Offset of axis 1 in [nm] 
		offset_axis1 
		Offset of axis 2 in [nm] 
		offset_axis2 
		Offset of axis 3 in [nm] 
 Returns:
		int32 
		Error code, if there was an error, otherwise 0 for ok 
		JSON Method 
		 
=cut
sub updateOffsets {
	my ($self, $offset_axis0, $offset_axis1, $offset_axis2, %args) = validated_list(
		offset_axis0	=> {, optional => 0,},
		offset_axis1	=> {, optional => 0,},
		offset_axis2	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rotcomp.updateOffsets', params => [$offset_axis0, $offset_axis1, $offset_axis2])

	self->handle_error($response)

	return response
}

=head2 apply
 Description:
		  Apply all realtime input function 
 Arguments:
 Returns:
		JSON Method 
		 
=cut
sub apply {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.rtin.apply')

	self->handle_error($response)

	return response
}

=head2 discard
 Description:
		  Discard all values beting set and not yet applieds 
 Arguments:
 Returns:
		JSON Method 
		 
=cut
sub discard {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.rtin.discard')

	self->handle_error($response)

	return response
}

=head2 getControlAQuadBInResolution
 Description:
		  This function gets the AQuadB input resolution for setpoint parameter. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		resolution 
		ion nm 
		JSON Method 
		 
=cut
sub getControlAQuadBInResolution {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.getControlAQuadBInResolution', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlMoveGPIO
 Description:
		  This function gets the status for real time input on the selected axis in closed-loop mode. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		enable 
		boolean true: approach enabled , false: approach disabled 
		JSON Method 
		 
=cut
sub getControlMoveGPIO {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.getControlMoveGPIO', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getGpioMode
 Description:
		  get the GPIO mode for Mic Mode feature 
 Arguments:
 Returns:
		gpio_mode 
		gpio_mode: 0: Standard GPIO 1: NSL-/Mic-Mode 
		JSON Method 
		 
=cut
sub getGpioMode {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.rtin.getGpioMode')

	self->handle_error($response)

	return response
}

=head2 getNslMux
 Description:
		  get the axis the NSL multiplexer is set to 
 Arguments:
		mux_mode 
		[0|1|2|3] 
		0: Off 
		1: Axis 1 
		2: Axis 2 
		3: Axis 3 
 Returns:
		JSON Method 
		 
=cut
sub getNslMux {
	my ($self, $mux_mode, %args) = validated_list(
		mux_mode	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.getNslMux', params => [$mux_mode])

	self->handle_error($response)

	return response
}

=head2 getRealTimeInChangePerPulse
 Description:
		  This function gets the change per pulse for the selected axis under real time input in the closed-loop mode. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		resolution 
		to be added in current pos in nm 
		JSON Method 
		 
=cut
sub getRealTimeInChangePerPulse {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.getRealTimeInChangePerPulse', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getRealTimeInFeedbackLoopMode
 Description:
		  Get if the realtime function must operate in close loop operation or open loop operation 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		mode 
		0: open loop, 1 : close-loop 
		JSON Method 
		 
=cut
sub getRealTimeInFeedbackLoopMode {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.getRealTimeInFeedbackLoopMode', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getRealTimeInMode
 Description:
		  This function sets or gets the real time input mode for the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		mode 
		see `RT_IN_MODES` 
		JSON Method 
		 
=cut
sub getRealTimeInMode {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.getRealTimeInMode', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getRealTimeInStepsPerPulse
 Description:
		  Get the change in step per pulse  of the realtime input when trigger and stepper mode is used 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		steps 
		number of steps to applied 
		JSON Method 
		 
=cut
sub getRealTimeInStepsPerPulse {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.getRealTimeInStepsPerPulse', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 setControlAQuadBInResolution
 Description:
		  This function sets the AQuadB input resolution for setpoint parameter. 
 Arguments:
		axis 
		[0|1|2] 
		resolution 
		ion nm 
 Returns:
		JSON Method 
		 
=cut
sub setControlAQuadBInResolution {
	my ($self, $axis, $resolution, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		resolution	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.setControlAQuadBInResolution', params => [$axis, $resolution])

	self->handle_error($response)

	return response
}

=head2 setControlMoveGPIO
 Description:
		  This function sets the status for real time input on the selected axis in closed-loop mode. 
 Arguments:
		axis 
		[0|1|2] 
		enable 
		boolean true: eanble the approach , false: disable the approach 
 Returns:
		JSON Method 
		 
=cut
sub setControlMoveGPIO {
	my ($self, $axis, $enable, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		enable	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.setControlMoveGPIO', params => [$axis, $enable])

	self->handle_error($response)

	return response
}

=head2 setGpioMode
 Description:
		  set the GPIO mode for Mic Mode feature 
 Arguments:
		gpio_mode 
		[0|1] 
		0: Standard GPIO 
		1: NSL-/Mic-Mode 
 Returns:
		JSON Method 
		 
=cut
sub setGpioMode {
	my ($self, $gpio_mode, %args) = validated_list(
		gpio_mode	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.setGpioMode', params => [$gpio_mode])

	self->handle_error($response)

	return response
}

=head2 setNslMux
 Description:
		  set the axis the NSL multiplexer is set to 
 Arguments:
		mux_mode 
		[0|1|2|3] 
		0: Off 
		1: Axis 1 
		2: Axis 2 
		3: Axis 3 
 Returns:
		JSON Method 
		 
=cut
sub setNslMux {
	my ($self, $mux_mode, %args) = validated_list(
		mux_mode	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.setNslMux', params => [$mux_mode])

	self->handle_error($response)

	return response
}

=head2 setRealTimeInChangePerPulse
 Description:
		  This function sets the change per pulse for the selected axis under real time input in the closed-loop mode. only used in closed loop operation 
 Arguments:
		axis 
		[0|1|2] 
		delta 
		to be added to current position in nm 
 Returns:
		JSON Method 
		 
=cut
sub setRealTimeInChangePerPulse {
	my ($self, $axis, $delta, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		delta	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.setRealTimeInChangePerPulse', params => [$axis, $delta])

	self->handle_error($response)

	return response
}

=head2 setRealTimeInFeedbackLoopMode
 Description:
		  Set if the realtime function must operate in close loop operation or open loop operation 
 Arguments:
		axis 
		[0|1|2] 
		mode 
		0: open loop, 1 : close-loop 
 Returns:
		JSON Method 
		 
=cut
sub setRealTimeInFeedbackLoopMode {
	my ($self, $axis, $mode, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		mode	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.setRealTimeInFeedbackLoopMode', params => [$axis, $mode])

	self->handle_error($response)

	return response
}

=head2 setRealTimeInMode
 Description:
		  This function sets the real time input mode for the selected axis. 
 Arguments:
		axis 
		[0|1|2] 
		mode 
		see `RT_IN_MODES` @see realtime 
 Returns:
		JSON Method 
		 
=cut
sub setRealTimeInMode {
	my ($self, $axis, $mode, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		mode	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.setRealTimeInMode', params => [$axis, $mode])

	self->handle_error($response)

	return response
}

=head2 setRealTimeInStepsPerPulse
 Description:
		  Set the change in step per pulse  of the realtime input when trigger and stepper mode is used only used in open loop operation 
 Arguments:
		axis 
		[0|1|2] 
		steps 
		number of steps to applied 
 Returns:
		JSON Method 
		 
=cut
sub setRealTimeInStepsPerPulse {
	my ($self, $axis, $steps, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		steps	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtin.setRealTimeInStepsPerPulse', params => [$axis, $steps])

	self->handle_error($response)

	return response
}

=head2 apply
 Description:
		  Apply for all rtout function 
 Arguments:
 Returns:
		JSON Method 
		 
=cut
sub apply {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.rtout.apply')

	self->handle_error($response)

	return response
}

=head2 applyAxis
 Description:
		  Apply for rtout function of specific axis 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		JSON Method 
		 
=cut
sub applyAxis {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtout.applyAxis', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 discard
 Description:
		  Discard all rtout value set by the set function(not applied yet) 
 Arguments:
 Returns:
		JSON Method 
		 
=cut
sub discard {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.rtout.discard')

	self->handle_error($response)

	return response
}

=head2 discardAxis
 Description:
		  Discard rtout value of specific axis set by the set function(not applied yet) 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		JSON Method 
		 
=cut
sub discardAxis {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtout.discardAxis', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 discardSignalMode
 Description:
		  Discard value set by setSignalMode 
 Arguments:
 Returns:
		JSON Method 
		 
=cut
sub discardSignalMode {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.rtout.discardSignalMode')

	self->handle_error($response)

	return response
}

=head2 getControlAQuadBOut
 Description:
		  This function gets if of AQuadB output for position indication is enabled 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		enabled 
		boolean 
		JSON Method 
		 
=cut
sub getControlAQuadBOut {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtout.getControlAQuadBOut', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlAQuadBOutClock
 Description:
		  This function gets the clock for AQuadB output. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		clock_in_ns 
		Clock in multiples of 20ns. Minimum 2 (40ns), maximum 65535 
		(1,310700ms) 
		JSON Method 
		 
=cut
sub getControlAQuadBOutClock {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtout.getControlAQuadBOutClock', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getControlAQuadBOutResolution
 Description:
		  This function gets the AQuadB output resolution for position indication. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		resolution 
		in nm 
		JSON Method 
		 
=cut
sub getControlAQuadBOutResolution {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtout.getControlAQuadBOutResolution', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getMode
 Description:
		  Get Mode 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		mode 
		0: Off, 1: AquadB, 2: Trigger 
		JSON Method 
		 
=cut
sub getMode {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtout.getMode', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getSignalMode
 Description:
		  This function gets the real time output mode for the selected axis. 
 Arguments:
 Returns:
		mode 
		0: TTL, 1: LVDS 
		JSON Method 
		 
=cut
sub getSignalMode {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.amc.rtout.getSignalMode')

	self->handle_error($response)

	return response
}

=head2 getTriggerConfig
 Description:
		  Get the real time output trigger config 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		higher 
		upper limit in nm / µdeg 
		lower 
		lower limit in nm / µdeg 
		epsilon 
		hysteresis in nm / µdeg 
		polarity 
		0: active high, 1: active low 
		JSON Method 
		 
=cut
sub getTriggerConfig {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtout.getTriggerConfig', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 setControlAQuadBOutClock
 Description:
		  This function sets the clock for AQuadB output. 
 Arguments:
		axis 
		[0|1|2] 
		clock 
		Clock in multiples of 20ns. Minimum 2 (40ns), maximum 65535 
		(1,310700ms) 
 Returns:
		JSON Method 
		 
=cut
sub setControlAQuadBOutClock {
	my ($self, $axis, $clock, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		clock	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtout.setControlAQuadBOutClock', params => [$axis, $clock])

	self->handle_error($response)

	return response
}

=head2 setControlAQuadBOutResolution
 Description:
		  This function sets the AQuadB output resolution for position indication. 
 Arguments:
		axis 
		[0|1|2] 
		resolution 
		in nm 
 Returns:
		JSON Method 
		 
=cut
sub setControlAQuadBOutResolution {
	my ($self, $axis, $resolution, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		resolution	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtout.setControlAQuadBOutResolution', params => [$axis, $resolution])

	self->handle_error($response)

	return response
}

=head2 setMode
 Description:
		  Set the real time output signal mode 
 Arguments:
		axis 
		[0|1|2] 
		mode 
		0: Off, 1: AquadB, 2: Trigger 
 Returns:
		JSON Method 
		 
=cut
sub setMode {
	my ($self, $axis, $mode, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		mode	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtout.setMode', params => [$axis, $mode])

	self->handle_error($response)

	return response
}

=head2 setSignalMode
 Description:
		  This function sets the real time output mode for the selected axis. 
 Arguments:
		mode 
		0: TTL, 1: LVDS 
 Returns:
		JSON Method 
		 
=cut
sub setSignalMode {
	my ($self, $mode, %args) = validated_list(
		mode	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtout.setSignalMode', params => [$mode])

	self->handle_error($response)

	return response
}

=head2 setTriggerConfig
 Description:
		  Control the real time output trigger config 
 Arguments:
		axis 
		[0|1|2] 
		higher 
		upper limit in nm / µdeg 
		lower 
		lower limit in nm / µdeg 
		epsilon 
		hysteresis in nm / µdeg 
		polarity 
		0: active high, 1: active low 
 Returns:
		JSON Method 
		 
=cut
sub setTriggerConfig {
	my ($self, $axis, $higher, $lower, $epsilon, $polarity, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
		higher	=> {, optional => 0,},
		lower	=> {, optional => 0,},
		epsilon	=> {, optional => 0,},
		polarity	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.rtout.setTriggerConfig', params => [$axis, $higher, $lower, $epsilon, $polarity])

	self->handle_error($response)

	return response
}

=head2 getFullCombinedStatus
 Description:
		  Get the full combined status of a positioner axis and return the status as a string (to be used in the Webapplication) 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		value_string1 
		string can be "moving","in target range", "backward limit 
		reached", "forward limit reached", "positioner not connected", 
		"grounded" (only AMC300), "output not enabled" 
		JSON Method 
		 
=cut
sub getFullCombinedStatus {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.status.getFullCombinedStatus', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getOlStatus
 Description:
		  Get the Feedback status of the positioner 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		sensorstatus 
		as integer 0: NUM Positioner connected 1: OL positioner 
		connected  2: No positioner connected , 3: RES positione connected 
		JSON Method 
		 
=cut
sub getOlStatus {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.status.getOlStatus', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getStatusConnected
 Description:
		  This function gets information about the connection status of the selected axis’ positioner. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		connected 
		If true, the actor is connected 
		JSON Method 
		 
=cut
sub getStatusConnected {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.status.getStatusConnected', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getStatusEot
 Description:
		  Retrieves the status of the end of travel (EOT) detection in backward direction or in forward direction. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		detected 
		true when EoT in either direction was detected 
		JSON Method 
		 
=cut
sub getStatusEot {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.status.getStatusEot', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getStatusEotBkwd
 Description:
		  This function gets the status of the end of travel detection on the selected axis in backward direction. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		detected 
		true when EoT was detected 
		JSON Method 
		 
=cut
sub getStatusEotBkwd {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.status.getStatusEotBkwd', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getStatusEotFwd
 Description:
		  This function gets the status of the end of travel detection on the selected axis in forward direction. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		detected 
		true when EoT was detected 
		JSON Method 
		 
=cut
sub getStatusEotFwd {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.status.getStatusEotFwd', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getStatusMoving
 Description:
		  This function gets information about the status of the stage output. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		status 
		0: Idle, i.e. within the noise range of the sensor, 1: Moving, i.e the 
		actor is actively driven by the output stage either for closed-loop 
		approach or continous/single stepping and the output is active. 
		2 : Pending means the output stage is driving but the output is 
		deactivated 
		JSON Method 
		 
=cut
sub getStatusMoving {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.status.getStatusMoving', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getStatusReference
 Description:
		  This function gets information about the status of the reference position. 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		valid 
		true = valid, false = not valid 
		JSON Method 
		 
=cut
sub getStatusReference {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.status.getStatusReference', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getStatusTargetRange
 Description:
		  This function gets information about whether the selected axis’ positioner is in target range or not. The detection only indicates whether the position is within the defined range. This status is updated periodically but currently not in real-time. If a fast detection is desired, please check the position in a loop 
 Arguments:
		axis 
		[0|1|2] 
 Returns:
		in_range 
		true within the target range, false not within the target range 
		JSON Method 
		 
=cut
sub getStatusTargetRange {
	my ($self, $axis, %args) = validated_list(
		axis	=> {isa => enum([ qw(0 1 2 ) ]), optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.amc.status.getStatusTargetRange', params => [$axis])

	self->handle_error($response)

	return response
}

=head2 getInstalledPackages
 Description:
		  Get list of packages installed on the device 
 Arguments:
 Returns:
		errorCode 
		value_string1 
		string: Comma separated list of packages 
		JSON Method 
		 
=cut
sub getInstalledPackages {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.about.getInstalledPackages')

	self->handle_error($response)

	return response
}

=head2 getPackageLicense
 Description:
		  Get the license for a specific package 
 Arguments:
		pckg 
		string: Package name 
 Returns:
		errorCode 
		value_string1 
		string: License for this package 
		JSON Method 
		 
=cut
sub getPackageLicense {
	my ($self, $pckg, %args) = validated_list(
		pckg	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.about.getPackageLicense', params => [$pckg])

	self->handle_error($response)

	return response
}

=head2 apply
 Description:
		  Apply temporary system configuration 
 Arguments:
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub apply {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.apply')

	self->handle_error($response)

	return response
}

=head2 errorNumberToRecommendation
 Description:
		  Get a recommendation for the error code 
 Arguments:
		language 
		integer: Language code 
		errNbr 
		interger: Error code to translate 
 Returns:
		errorCode 
		value_string1 
		string: Error recommendation (currently returning an int = 0 until 
		we have recommendations) 
		JSON Method 
		 
=cut
sub errorNumberToRecommendation {
	my ($self, $language, $errNbr, %args) = validated_list(
		language	=> {, optional => 0,},
		errNbr	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.errorNumberToRecommendation', params => [$language, $errNbr])

	self->handle_error($response)

	return response
}

=head2 errorNumberToString
 Description:
		  Get a description of an error code 
 Arguments:
		language 
		integer: Language code 0 for the error name, 1 for a more user 
		friendly error message 
		errNbr 
		interger: Error code to translate 
 Returns:
		errorCode 
		value_string1 
		string: Error description 
		JSON Method 
		 
=cut
sub errorNumberToString {
	my ($self, $language, $errNbr, %args) = validated_list(
		language	=> {, optional => 0,},
		errNbr	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.errorNumberToString', params => [$language, $errNbr])

	self->handle_error($response)

	return response
}

=head2 factoryReset
 Description:
		  Turns on the factory reset flag. To perform the factory reset, a reboot is necessary afterwards. All settings will be set to default and the IDS will be configured as DHCP server. 
 Arguments:
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub factoryReset {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.factoryReset')

	self->handle_error($response)

	return response
}

=head2 checkAMCinRack
 Description:
		  If AMC is on Rack position 0, use it as DHCP server, else use it as DHCP client 
 Arguments:
 Returns:
=cut
sub checkAMCinRack {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.functions.checkAMCinRack')

	self->handle_error($response)

	return response
}

=head2 getDeviceName
 Description:
		  Get the actual device name 
 Arguments:
 Returns:
		errorCode 
		value_string1 
		string: actual device name 
		JSON Method 
		 
=cut
sub getDeviceName {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.getDeviceName')

	self->handle_error($response)

	return response
}

=head2 getFirmwareVersion
 Description:
		  Get the firmware version of the system 
 Arguments:
 Returns:
		errorCode 
		value_string1 
		string: The firmware version 
		JSON Method 
		 
=cut
sub getFirmwareVersion {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.getFirmwareVersion')

	self->handle_error($response)

	return response
}

=head2 getFluxCode
 Description:
		  Get the flux code of the system 
 Arguments:
 Returns:
		errorCode 
		value_string1 
		string: flux code 
		JSON Method 
		 
=cut
sub getFluxCode {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.getFluxCode')

	self->handle_error($response)

	return response
}

=head2 getHostname
 Description:
		  Return device hostname 
 Arguments:
 Returns:
		errorCode 
		available 
		available 
		JSON Method 
		 
=cut
sub getHostname {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.getHostname')

	self->handle_error($response)

	return response
}

=head2 getMacAddress
 Description:
		  Get the mac address of the system 
 Arguments:
 Returns:
		errorCode 
		value_string1 
		string: Mac address of the system 
		JSON Method 
		 
=cut
sub getMacAddress {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.getMacAddress')

	self->handle_error($response)

	return response
}

=head2 getSerialNumber
 Description:
		  Get the serial number of the system 
 Arguments:
 Returns:
		errorCode 
		value_string1 
		string: Serial number 
		JSON Method 
		 
=cut
sub getSerialNumber {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.getSerialNumber')

	self->handle_error($response)

	return response
}

=head2 apply
 Description:
		  Apply temporary IP configuration and load it 
 Arguments:
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub apply {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.apply')

	self->handle_error($response)

	return response
}

=head2 configureWifi
 Description:
		  Change the wifi configuration and applies it 
 Arguments:
		mode 
		0: Access point, 1: Wifi client 
		ssid 
		 
		psk 
		Pre-shared key 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub configureWifi {
	my ($self, $mode, $ssid, $psk, %args) = validated_list(
		mode	=> {, optional => 0,},
		ssid	=> {, optional => 0,},
		psk	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.network.configureWifi', params => [$mode, $ssid, $psk])

	self->handle_error($response)

	return response
}

=head2 discard
 Description:
		  Discard temporary IP configuration 
 Arguments:
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub discard {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.discard')

	self->handle_error($response)

	return response
}

=head2 getDefaultGateway
 Description:
		  Get the default gateway of the device 
 Arguments:
 Returns:
		errorCode 
		Default 
		gateway 
		JSON Method 
		 
=cut
sub getDefaultGateway {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.getDefaultGateway')

	self->handle_error($response)

	return response
}

=head2 getDnsResolver
 Description:
		  Get the DNS resolver 
 Arguments:
		priority 
		of DNS resolver (Usually: 0 = Default, 1 = Backup) 
 Returns:
		errorCode 
		IP 
		address of DNS resolver 
		JSON Method 
		 
=cut
sub getDnsResolver {
	my ($self, $priority, %args) = validated_list(
		priority	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.network.getDnsResolver', params => [$priority])

	self->handle_error($response)

	return response
}

=head2 getEnableDhcpClient
 Description:
		  Get the state of DHCP client 
 Arguments:
 Returns:
		errorCode 
		value_boolean1 
		boolean: true = DHCP client enable, false = DHCP client disable 
		JSON Method 
		 
=cut
sub getEnableDhcpClient {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.getEnableDhcpClient')

	self->handle_error($response)

	return response
}

=head2 getEnableDhcpServer
 Description:
		  Get the state of DHCP server 
 Arguments:
 Returns:
		errorCode 
		value_boolean1 
		boolean: true = DHCP server enable, false = DHCP server disable 
		JSON Method 
		 
=cut
sub getEnableDhcpServer {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.getEnableDhcpServer')

	self->handle_error($response)

	return response
}

=head2 getIpAddress
 Description:
		  Get the IP address of the device 
 Arguments:
 Returns:
		errorCode 
		IP 
		address as string 
		JSON Method 
		 
=cut
sub getIpAddress {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.getIpAddress')

	self->handle_error($response)

	return response
}

=head2 getProxyServer
 Description:
		  Get the proxy settings of the devide 
 Arguments:
 Returns:
		errorCode 
		Proxy 
		Server String, empty for no proxy 
		JSON Method 
		 
=cut
sub getProxyServer {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.getProxyServer')

	self->handle_error($response)

	return response
}

=head2 getRealIpAddress
 Description:
		  Get the real IP address of the device set to the network interface (br0, eth1 or eth0) 
 Arguments:
 Returns:
		errorCode 
		IP 
		address as string 
		JSON Method 
		 
=cut
sub getRealIpAddress {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.getRealIpAddress')

	self->handle_error($response)

	return response
}

=head2 getSubnetMask
 Description:
		  Get the subnet mask of the device 
 Arguments:
 Returns:
		errorCode 
		Subnet 
		mask as string 
		JSON Method 
		 
=cut
sub getSubnetMask {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.getSubnetMask')

	self->handle_error($response)

	return response
}

=head2 getWifiMode
 Description:
		  Get the operation mode of the wifi adapter 
 Arguments:
 Returns:
		errorCode 
		mode 
		0: Access point, 1: Wifi client 
		JSON Method 
		 
=cut
sub getWifiMode {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.getWifiMode')

	self->handle_error($response)

	return response
}

=head2 getWifiPassphrase
 Description:
		  Get the the passphrase of the network hosted (mode: Access point) or connected to (mode: client) 
 Arguments:
 Returns:
		errorCode 
		psk 
		Pre-shared key 
		JSON Method 
		 
=cut
sub getWifiPassphrase {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.getWifiPassphrase')

	self->handle_error($response)

	return response
}

=head2 getWifiPresent
 Description:
		  Returns is a Wifi interface is present 
 Arguments:
 Returns:
		errorCode 
		True 
		True, if interface is present 
		JSON Method 
		 
=cut
sub getWifiPresent {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.getWifiPresent')

	self->handle_error($response)

	return response
}

=head2 getWifiSSID
 Description:
		  Get the the SSID of the network hosted (mode: Access point) or connected to (mode: client) 
 Arguments:
 Returns:
		errorCode 
		SSID 
		SSID 
		JSON Method 
		 
=cut
sub getWifiSSID {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.getWifiSSID')

	self->handle_error($response)

	return response
}

=head2 setDefaultGateway
 Description:
		  Set the default gateway of the device 
 Arguments:
		gateway 
		Default gateway as string 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setDefaultGateway {
	my ($self, $gateway, %args) = validated_list(
		gateway	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.network.setDefaultGateway', params => [$gateway])

	self->handle_error($response)

	return response
}

=head2 setDnsResolver
 Description:
		  Set the DNS resolver 
 Arguments:
		priority 
		of DNS resolver (Usually: 0 = Default, 1 = Backup) 
		resolver 
		The resolver's IP address as string 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setDnsResolver {
	my ($self, $priority, $resolver, %args) = validated_list(
		priority	=> {, optional => 0,},
		resolver	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.network.setDnsResolver', params => [$priority, $resolver])

	self->handle_error($response)

	return response
}

=head2 setEnableDhcpClient
 Description:
		  Enable or disable DHCP client 
 Arguments:
		enable 
		boolean: true = enable DHCP client, false = disable DHCP client 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setEnableDhcpClient {
	my ($self, $enable, %args) = validated_list(
		enable	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.network.setEnableDhcpClient', params => [$enable])

	self->handle_error($response)

	return response
}

=head2 setEnableDhcpServer
 Description:
		  Enable or disable DHCP server 
 Arguments:
		enable 
		boolean: true = enable DHCP server, false = disable DHCP server 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setEnableDhcpServer {
	my ($self, $enable, %args) = validated_list(
		enable	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.network.setEnableDhcpServer', params => [$enable])

	self->handle_error($response)

	return response
}

=head2 setIpAddress
 Description:
		  Set the IP address of the device 
 Arguments:
		address 
		IP address as string 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setIpAddress {
	my ($self, $address, %args) = validated_list(
		address	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.network.setIpAddress', params => [$address])

	self->handle_error($response)

	return response
}

=head2 setProxyServer
 Description:
		  Set the proxy server of the device 
 Arguments:
		proxyServer 
		Proxy Server Setting as string 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setProxyServer {
	my ($self, $proxyServer, %args) = validated_list(
		proxyServer	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.network.setProxyServer', params => [$proxyServer])

	self->handle_error($response)

	return response
}

=head2 setSubnetMask
 Description:
		  Set the subnet mask of the device 
 Arguments:
		netmask 
		Subnet mask as string 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setSubnetMask {
	my ($self, $netmask, %args) = validated_list(
		netmask	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.network.setSubnetMask', params => [$netmask])

	self->handle_error($response)

	return response
}

=head2 setWifiMode
 Description:
		  Change the operation mode of the wifi adapter 
 Arguments:
		mode 
		0: Access point, 1: Wifi client 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setWifiMode {
	my ($self, $mode, %args) = validated_list(
		mode	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.network.setWifiMode', params => [$mode])

	self->handle_error($response)

	return response
}

=head2 setWifiPassphrase
 Description:
		  Change the passphrase of the network hosted (mode: Access point) or connected to (mode: client) 
 Arguments:
		psk 
		Pre-shared key 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setWifiPassphrase {
	my ($self, $psk, %args) = validated_list(
		psk	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.network.setWifiPassphrase', params => [$psk])

	self->handle_error($response)

	return response
}

=head2 setWifiSSID
 Description:
		  Change the SSID of the network hosted (mode: Access point) or connected to (mode: client) 
 Arguments:
		ssid 
		 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setWifiSSID {
	my ($self, $ssid, %args) = validated_list(
		ssid	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.network.setWifiSSID', params => [$ssid])

	self->handle_error($response)

	return response
}

=head2 verify
 Description:
		  Verify that temporary IP configuration is correct 
 Arguments:
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub verify {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.network.verify')

	self->handle_error($response)

	return response
}

=head2 rebootSystem
 Description:
		  Reboot the system 
 Arguments:
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub rebootSystem {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.rebootSystem')

	self->handle_error($response)

	return response
}

=head2 setDeviceName
 Description:
		  Set custom name for the device 
 Arguments:
		name 
		string: device name 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setDeviceName {
	my ($self, $name, %args) = validated_list(
		name	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.setDeviceName', params => [$name])

	self->handle_error($response)

	return response
}

=head2 setTime
 Description:
		  Set system time manually 
 Arguments:
		day 
		integer: Day (1-31) 
		month 
		integer: Day (1-12) 
		year 
		integer: Day (eg. 2021) 
		hour 
		integer: Day (0-23) 
		minute 
		integer: Day (0-59) 
		second 
		integer: Day (0-59) 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub setTime {
	my ($self, $day, $month, $year, $hour, $minute, $second, %args) = validated_list(
		day	=> {, optional => 0,},
		month	=> {, optional => 0,},
		year	=> {, optional => 0,},
		hour	=> {, optional => 0,},
		minute	=> {, optional => 0,},
		second	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.setTime', params => [$day, $month, $year, $hour, $minute, $second])

	self->handle_error($response)

	return response
}

=head2 softReset
 Description:
		  Performs a soft reset (Reset without deleting the network settings). Please reboot the device directly afterwards. 
 Arguments:
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub softReset {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.softReset')

	self->handle_error($response)

	return response
}

=head2 updateTimeFromInternet
 Description:
		  Update system time by querying attocube.com 
 Arguments:
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub updateTimeFromInternet {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.updateTimeFromInternet')

	self->handle_error($response)

	return response
}

=head2 getLicenseUpdateProgress
 Description:
		  Get the progress of running license update 
 Arguments:
 Returns:
		errorCode 
		value_int1 
		int: progress in percent 
		JSON Method 
		 
=cut
sub getLicenseUpdateProgress {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.update.getLicenseUpdateProgress')

	self->handle_error($response)

	return response
}

=head2 getSwUpdateProgress
 Description:
		  Get the progress of running update 
 Arguments:
 Returns:
		errorCode 
		value_int1 
		int: progress in percent 
		JSON Method 
		 
=cut
sub getSwUpdateProgress {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.update.getSwUpdateProgress')

	self->handle_error($response)

	return response
}

=head2 licenseUpdateBase64
 Description:
		  Execute the license update with base64 file uploaded. After execution, a manual reboot is nevessary. 
 Arguments:
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub licenseUpdateBase64 {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.update.licenseUpdateBase64')

	self->handle_error($response)

	return response
}

=head2 softwareUpdateBase64
 Description:
		  Execute the update with base64 file uploaded. After completion, a manual reboot is necessary. 
 Arguments:
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub softwareUpdateBase64 {
	my ($self) = shift

	my $response = $self->request(method => 'com.attocube.system.update.softwareUpdateBase64')

	self->handle_error($response)

	return response
}

=head2 uploadLicenseBase64
 Description:
		  Upload new license file in format base 64 
 Arguments:
		offset 
		int: offset of the data 
		b64Data 
		string: base64 data 
 Returns:
		errorCode 
		JSON Method 
		 
=cut
sub uploadLicenseBase64 {
	my ($self, $offset, $b64Data, %args) = validated_list(
		offset	=> {, optional => 0,},
		b64Data	=> {, optional => 0,},
	);

	my $response = $self->request(method => 'com.attocube.system.update.uploadLicenseBase64', params => [$offset, $b64Data])

	self->handle_error($response)

	return response
}

# (9)
__PACKAGE__->meta()->make_immutable();
1;
