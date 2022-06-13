# Copyright (c) AudioKit, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

Pod::Spec.new do |spec|
  spec.name = 'AudioKitEX'
  spec.version = '5.4.0'
  spec.license =  { :type => 'MIT', :file => "LICENSE" }
  spec.homepage = 'https://audiokit.io/'
  spec.documentation_url = 'http://audiokit.io/docs/'

  spec.summary = 'Open-source audio synthesis, processing, & analysis platform.'
  spec.description = 'Open-source audio synthesis, processing, & analysis platform.'

  spec.authors = 'Aurelius Prochazka'
  spec.source = {
    :git => 'https://github.com/mzf414/AudioKitEX.git',
    :tag => spec.version.to_s,
  }
  spec.platforms = { :ios => "11.0", :osx => "10.13", :tvos => "11.0" }
  spec.module_name = 'AudioKitEX'
  spec.requires_arc = false
  spec.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
  spec.source_files = 'Sources/**/*.{c,h,cpp,swift}'
  spec.public_header_files = 'Sources/**/*.{h}'
  spec.swift_version = '5.0'
end
