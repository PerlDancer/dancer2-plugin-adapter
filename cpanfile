requires "Class::Load" => "0";
requires "Dancer2" => "0";
requires "Dancer2::Plugin" => "0";
requires "perl" => "5.008001";
requires "strict" => "0";
requires "warnings" => "0";
recommends "Class::Load::XS" => "0";
recommends "Dancer2" => "0.153000";

on 'test' => sub {
  requires "File::Spec" => "0";
  requires "File::Temp" => "0.19";
  requires "HTTP::Request::Common" => "0";
  requires "HTTP::Tiny" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "JSON" => "0";
  requires "Plack::Test" => "0";
  requires "Test::More" => "0.96";
};

on 'test' => sub {
  recommends "WWW::Postmark" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "version" => "0.9901";
};
