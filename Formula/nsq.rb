class Nsq < Formula
  desc "Realtime distributed messaging platform"
  homepage "https://nsq.io/"
  url "https://github.com/nsqio/nsq/archive/v1.2.0.tar.gz"
  sha256 "98e24d748550f01dd8775e5e40f3ae657f5b513f875a15081cdcdc567b745480"
  license "MIT"
  head "https://github.com/nsqio/nsq.git"

  bottle do
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_big_sur: "b3085b1fbf198c51c7afb142f709bcaa183337b7cb7dbb59c2b5ef9991c2df88"
    sha256 cellar: :any_skip_relocation, big_sur:       "105dd8083fcde66eb333a1495a8e06da2701f2e9cc6e17ed434dce0a7c38e162"
    sha256 cellar: :any_skip_relocation, catalina:      "2aae6c19e55ebd926426301fa85dd5716bce20a04bfbc11a5519dbada6a67368"
    sha256 cellar: :any_skip_relocation, mojave:        "bffff40b52e50eb181b9a02c8650b51924e45e8d650a5ed17051b8b1c0ce46cc"
    sha256 cellar: :any_skip_relocation, high_sierra:   "96ead21ddbb8f6f004141aac2e7c5a23d8740eaa5d4730eb4b0d6d94a0b63683"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "239affa65e2bb7032ed29ca2ae8afd3cc5b2d30507a77685c3321c6a6bdb192f"
  end

  depends_on "go" => :build

  def install
    system "make", "DESTDIR=#{prefix}", "PREFIX=", "install"
    prefix.install_metafiles
  end

  def post_install
    (var/"log").mkpath
    (var/"nsq").mkpath
  end

  plist_options manual: "nsqd -data-path=#{HOMEBREW_PREFIX}/var/nsq"

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
        <true/>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{bin}/nsqd</string>
          <string>-data-path=#{var}/nsq</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>WorkingDirectory</key>
        <string>#{var}/nsq</string>
        <key>StandardErrorPath</key>
        <string>#{var}/log/nsqd.error.log</string>
        <key>StandardOutPath</key>
        <string>#{var}/log/nsqd.log</string>
      </dict>
      </plist>
    EOS
  end

  test do
    lookupd = fork do
      exec bin/"nsqlookupd"
    end
    sleep 2
    d = fork do
      exec bin/"nsqd", "--lookupd-tcp-address=127.0.0.1:4160"
    end
    sleep 2
    admin = fork do
      exec bin/"nsqadmin", "--lookupd-http-address=127.0.0.1:4161"
    end
    sleep 2
    to_file = fork do
      exec bin/"nsq_to_file", "--lookupd-http-address=127.0.0.1:4161",
                              "--output-dir=#{testpath}",
                              "--topic=test"
    end
    sleep 2
    system "curl", "-d", "hello", "http://127.0.0.1:4151/pub?topic=test"
    sleep 2
    dat = File.read(Dir["*.dat"].first)
    assert_match "test", dat
    assert_match version.to_s, dat
  ensure
    Process.kill(15, lookupd)
    Process.kill(15, d)
    Process.kill(15, admin)
    Process.kill(15, to_file)
    Process.wait lookupd
    Process.wait d
    Process.wait admin
    Process.wait to_file
  end
end
