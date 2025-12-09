require "spec_setup"
require "tmpdir" # for Dir.mktmpdir
require "fpm" # local
require "fpm/package/cpan" # local

have_cpanm = program_exists?("cpanm")
if !have_cpanm
  Cabin::Channel.get("rspec") \
    .warn("Skipping CPAN tests because 'cpanm' isn't in your PATH")
end

describe FPM::Package::CPAN do
  before do
    skip("Missing cpanm program") unless have_cpanm
  end

  subject { FPM::Package::CPAN.new }

  after :each do
    subject.cleanup
  end

  it "should prepend package name prefix" do
    subject.attributes[:cpan_package_name_prefix] = "prefix"
    insist { subject.instance_eval { fix_name("Foo::Bar") } } == "prefix-Foo-Bar"
  end

  it "should wrap name in perl()" do
    insist { subject.instance_eval { cap_name("Foo::Bar") } } == "perl(Foo::Bar)"
  end

  it "should return successful HTTP resonse" do
    response = subject.instance_eval { httpfetch("https://fastapi.metacpan.org/v1/module/File::Temp") }
    insist { response.class } == Net::HTTPOK
  end

  it "should return successful HTTP resonse" do
    response = subject.instance_eval {httppost(
      "https://fastapi.metacpan.org/v1/release/_search",
      "{\"fields\":[\"download_url\"],\"filter\":{\"term\":{\"name\":\"File-Temp-0.2310\"}}}"
    )}
    insist { response.class } == Net::HTTPOK
  end

  it "should return metadata hash" do
    metadata = subject.instance_eval { search("File::Temp") }
    insist { metadata.class } == Hash
    insist { metadata["name"] } == "Temp.pm"
    insist { metadata["distribution"] } == "File-Temp"
  end

  it "should download precise version" do
    metadata = subject.instance_eval { search("Set::Tiny") }
    insist { File.basename(subject.instance_eval { download(metadata, "0.01") }) } == "Set-Tiny-0.01.tar.gz"
  end

  it "should be normalize versions to dotted-decimal" do
    subject.attributes[:cpan_test?] = false

    # Mail::Box version 3.012 is a good example to test against because it does
    # not have a version already in normalized form, has a ranged version
    # dependency, a non-versioned dependency, and an exact version
    # dependency. This covers all of our cases.
    subject.instance_variable_set(:@version, "3.012");

    subject.input("Mail::Box")
    insist { subject.version }  == "3.12.0"
    insist { subject.provides.sort }  == ["perl(Mail::Box) = 3.12.0"]
    insist { subject.dependencies.sort }  == ["perl(Carp)", "perl(Cwd)", "perl(Date::Parse)", "perl(Devel::GlobalDestruction) >= 0.90.0", "perl(Errno)", "perl(Fcntl)", "perl(File::Basename)", "perl(File::Compare)", "perl(File::Copy)", "perl(File::Remove) >= 0.200.0", "perl(File::Spec) >= 0.700.0", "perl(File::Temp)", "perl(IO::Scalar)", "perl(Mail::Message) < 4.0.0", "perl(Mail::Message) >= 3.13.0", "perl(Mail::Transport) < 4.0.0", "perl(Mail::Transport) >= 3.3.0", "perl(Object::Realize::Later) < 4.0.0", "perl(Object::Realize::Later) >= 0.190.0", "perl(POSIX)", "perl(Scalar::Util) >= 1.130.0", "perl(Sys::Hostname)"]
  end

  it "should package Digest::MD5" do
    # Set the version explicitly because we default to installing the newest
    # version, and a new version could be released that breaks the test.
    subject.instance_variable_set(:@version, "2.58");

    # Disable testing because we don't really need to run the cpan tests. The
    # goal is to see the parsed result (name, module description, etc)
    # Additionally, it fails on my workstation when cpan_test? is enabled due
    # to not finding `Test.pm`, and it seems like a flakey test if we keep this
    # enabled.
    subject.attributes[:cpan_test?] = false

    subject.input("Digest::MD5")
    insist { subject.name } == "perl-Digest-MD5"
    insist { subject.version } == "2.580.0"
    insist { subject.description } == "Perl interface to the MD-5 algorithm"
    insist { subject.vendor } == "Gisle Aas <gisle@activestate.com>"
    insist { subject.dependencies.sort } == ["perl >= 5.006", "perl(Digest::base) >= 1.0.0", "perl(XSLoader)"]
    insist { subject.provides.sort } == ["perl(Digest::MD5) = 2.580.0"]
  end

  it "should be able to disable version normalization" do
    subject.attributes[:cpan_normalize_versions?] = false
    subject.instance_variable_set(:@version, "2.58");
    subject.attributes[:cpan_test?] = false

    subject.input("Digest::MD5")
    insist { subject.version } == "2.58"
    insist { subject.dependencies.sort } == ["perl >= 5.006", "perl(Digest::base) >= 1.00", "perl(XSLoader)"]
    insist { subject.provides.sort } == ["perl(Digest::MD5) = 2.58"]
  end

  it "should unpack tarball containing ./ leading paths" do

    Dir.mktmpdir do |tmpdir|
      # Create tarball containing a file './foo/bar.txt'
      system("mkdir -p #{tmpdir}/z/foo")
      system("touch #{tmpdir}/z/foo/bar.txt")
      system("tar -C #{tmpdir} -cvzf #{tmpdir}/z.tar.gz .")

      # Invoke the unpack method
      directory = subject.instance_eval { unpack("#{tmpdir}/z.tar.gz") }

      insist { File.file?("#{directory}/foo/bar.txt") } == true
    end
  end

  it "should package File::Spec" do
    subject.instance_variable_set(:@version, "3.75");
    subject.attributes[:cpan_test?] = false

    subject.input("File::Spec")

    # the File::Spec module comes from the PathTools CPAN distribution
    insist { subject.name } == "perl-PathTools"
  end

  it "should package Class::Data::Inheritable" do
    # Class::Data::Inheritable version 0.08 has a blank author field in its
    # META.yml file.
    subject.instance_variable_set(:@version, "0.08");

    subject.attributes[:cpan_test?] = false

    subject.input("Class::Data::Inheritable")
    insist { subject.vendor } == "No Vendor Or Author Provided"
  end

  context "given a distribution without a META.* file" do
    it "should package IPC::Session" do
      subject.instance_variable_set(:@version, "0.05");
      subject.attributes[:cpan_test?] = false
      # IPC::Session fails 'make test'
      subject.input("IPC::Session")
    end
  end
end # describe FPM::Package::CPAN
