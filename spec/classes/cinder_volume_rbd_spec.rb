require 'spec_helper'

describe 'cinder::volume::rbd' do
  let :req_params do
    {
      :rbd_pool                         => 'volumes',
      :glance_api_version               => '2',
      :rbd_user                         => 'test',
      :rbd_secret_uuid                  => '0123456789',
      :rbd_ceph_conf                    => '/foo/boo/zoo/ceph.conf',
      :rbd_flatten_volume_from_snapshot => true,
      :volume_tmp_dir                   => '/foo/tmp',
      :rbd_max_clone_depth              => '0'
    }
  end

  it { should contain_class('cinder::params') }

  let :params do
    req_params
  end

  let :facts do
    {:osfamily => 'Debian'}
  end

  describe 'rbd volume driver' do
    it 'configure rbd volume driver' do
      should contain_cinder_config('DEFAULT/volume_driver').with_value('cinder.volume.drivers.rbd.RBDDriver')

      should contain_cinder_config('DEFAULT/rbd_ceph_conf').with_value(req_params[:rbd_ceph_conf])
      should contain_cinder_config('DEFAULT/rbd_flatten_volume_from_snapshot').with_value(req_params[:rbd_flatten_volume_from_snapshot])
      should contain_cinder_config('DEFAULT/volume_tmp_dir').with_value(req_params[:volume_tmp_dir])
      should contain_cinder_config('DEFAULT/rbd_max_clone_depth').with_value(req_params[:rbd_max_clone_depth])
      should contain_cinder_config('DEFAULT/rbd_pool').with_value(req_params[:rbd_pool])
      should contain_cinder_config('DEFAULT/rbd_user').with_value(req_params[:rbd_user])
      should contain_cinder_config('DEFAULT/rbd_secret_uuid').with_value(req_params[:rbd_secret_uuid])
      should contain_file('/etc/init/cinder-volume.override').with(:ensure => 'present')
      should contain_file_line('set initscript env').with(
        :line    => /env CEPH_ARGS=\"--id test\"/,
        :path    => '/etc/init/cinder-volume.override',
        :notify  => 'Service[cinder-volume]')
    end
  end

  describe 'with RedHat' do
    let :facts do
        { :osfamily => 'RedHat' }
    end

    let :params do
      req_params
    end

    it 'should ensure that the cinder-volume sysconfig file is present' do
      should contain_file('/etc/sysconfig/openstack-cinder-volume').with(
        :ensure => 'present'
      )
    end

    it 'should configure RedHat init override' do
      should contain_file_line('set initscript env').with(
        :line    => /export CEPH_ARGS=\"--id test\"/,
        :path    => '/etc/sysconfig/openstack-cinder-volume',
        :notify  => 'Service[cinder-volume]')
    end
  end

end

