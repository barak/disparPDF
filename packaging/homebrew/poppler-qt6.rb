class PopplerQt6 < Formula
  desc "Qt6 bindings for the Poppler PDF rendering library"
  homepage "https://poppler.freedesktop.org/"

  # keg が libpoppler を同梱するようになったため Homebrew の poppler とは独立だが、
  # PDF 解析エンジンが古いまま取り残されないよう poppler formula に合わせて上げる
  url "https://poppler.freedesktop.org/poppler-26.09.0.tar.xz"
  sha256 "8059eadb6805340768f138c465b57f8164c92b4a0773c37ef031ea6c0d987b2e"
  license any_of: ["GPL-2.0-only", "GPL-3.0-only"]

  # 以前は glib バインディングの mutex 初期化パッチを当てていたが、
  # このformulaは -DENABLE_GLIB=OFF でビルドしており一行も効いていなかったため削除した。

  depends_on "cmake"   => :build
  depends_on "pkgconf" => :build
  depends_on "qt@6"
  depends_on "poppler"
  depends_on "cairo"
  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "glib"
  depends_on "gpgmepp"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "libtiff"
  depends_on "little-cms2"
  depends_on "nspr"
  depends_on "nss"
  depends_on "openjpeg"
  on_macos do
    depends_on "gettext"
    depends_on "gpgme"
  end
  on_linux do
    depends_on "zlib-ng-compat"
  end

  keg_only "installs Qt6 Poppler headers that conflict with the poppler formula"

  def install
    poppler_prefix = Formula["poppler"].opt_prefix
    qt6_prefix     = Formula["qt@6"].opt_prefix

    args = std_cmake_args + %W[
      -DCMAKE_PREFIX_PATH=#{qt6_prefix};#{poppler_prefix}
      -DBUILD_GTK_TESTS=OFF
      -DBUILD_QT6_TESTS=OFF
      -DENABLE_BOOST=OFF
      -DENABLE_CMS=lcms2
      -DENABLE_GLIB=OFF
      -DENABLE_QT5=OFF
      -DENABLE_QT6=ON
      -DENABLE_UNSTABLE_API_ABI_HEADERS=ON
      -DWITH_GObjectIntrospection=OFF
      -DCMAKE_INSTALL_RPATH=#{rpath}
    ]

    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build", "--target", "poppler-qt6"

    # ── ヘッダ ──────────────────────────────────────────────────────────
    qt6_inc = include/"poppler/qt6"
    qt6_src = buildpath/"qt6/src"
    qt6_inc.install qt6_src/"poppler-qt6.h",
                    qt6_src/"poppler-annotation.h",
                    qt6_src/"poppler-converter.h",
                    qt6_src/"poppler-form.h",
                    qt6_src/"poppler-link.h",
                    qt6_src/"poppler-media.h",
                    qt6_src/"poppler-optcontent.h",
                    qt6_src/"poppler-page-transition.h"

    %w[poppler-export.h poppler-version.h].each do |hdr|
      found = Dir["#{buildpath}/build/**/#{hdr}"].first
      qt6_inc.install found if found
    end

    # ── ライブラリ ───────────────────────────────────────────────────────
    # libpoppler-qt6 と、それがリンクしている libpoppler 本体の両方を keg に入れる。
    #
    # 以前は Homebrew の poppler formula の dylib を参照するよう書き換えていたが、
    # poppler は ABI 安定性を保証しておらず soname (libpoppler.NNN.dylib) が
    # バージョンごとに変わる。そのため poppler が更新されるたびに参照先が消え、
    # 「Library not loaded: .../libpoppler.161.dylib」で起動できなくなっていた。
    # ここでは同じソースツリーからビルドした libpoppler を keg 内に同梱し、
    # Homebrew の poppler のバージョンから独立させる。
    lib.install Dir["build/qt6/src/libpoppler-qt6*"]

    core_dylibs = Dir["#{buildpath}/build/libpoppler.*.dylib"]
    core_dylibs = Dir["#{buildpath}/build/**/libpoppler.*.dylib"] if core_dylibs.empty?
    odie "libpoppler dylib not found in the build tree" if core_dylibs.empty?
    lib.install core_dylibs

    # 同梱した libpoppler の install name を keg 内の絶対パスにする
    Dir["#{lib}/libpoppler.*.dylib"].each do |core_dylib|
      next if File.symlink?(core_dylib)

      MachO::Tools.change_dylib_id(core_dylib, "#{lib}/#{File.basename(core_dylib)}")
      # 変更後に再署名（macOS 26以降はコード署名の変更を検出するため必須）
      system "codesign", "--force", "--sign", "-", core_dylib
    end

    # libpoppler-qt6 の @rpath 参照を、同梱した libpoppler の絶対パスへ書き換える。
    # soname は poppler のバージョンごとに変わるため決め打ちせず、
    # 実際のロードコマンドから読み取る。
    Dir["#{lib}/libpoppler-qt6.*.*.*.dylib"].each do |qt6_dylib|
      refs = MachO::MachOFile.new(qt6_dylib).linked_dylibs
      refs.grep(%r{\A@rpath/libpoppler\.[0-9.]+\.dylib\z}).each do |ref|
        MachO::Tools.change_install_name(qt6_dylib, ref, "#{lib}/#{File.basename(ref)}")
      end
      system "codesign", "--force", "--sign", "-", qt6_dylib
    end

    # ── pkg-config ───────────────────────────────────────────────────────
    # Qt6 バインディングのヘッダは自己完結しており poppler 本体の
    # ヘッダを必要としないため、Requires: poppler は付けない。
    # （付けると Homebrew の poppler の libpoppler も一緒にリンクされ、
    #   同梱したものと二重にロードされてしまう）
    (lib/"pkgconfig/poppler-qt6.pc").write <<~PC
      prefix=#{prefix}
      exec_prefix=${prefix}
      libdir=${prefix}/lib
      includedir=${prefix}/include

      Name: poppler-qt6
      Description: Qt6 bindings for poppler
      Version: #{version}
      Libs: -L${libdir} -lpoppler-qt6
      Cflags: -I${includedir}/poppler/qt6
    PC
  end

  test do
    system Formula["pkgconf"].opt_bin/"pkg-config", "--exists", "poppler-qt6"
  end
end
