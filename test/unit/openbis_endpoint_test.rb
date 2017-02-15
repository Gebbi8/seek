require 'test_helper'
require 'openbis_test_helper'

class OpenbisEndpointTest < ActiveSupport::TestCase

  def setup
    #avoids first person being admin
    person = Factory(:person)
    mock_openbis_calls
  end

  test 'validation' do
    project=Factory(:project)
    endpoint = OpenbisEndpoint.new project: project, username: 'fred', password: '12345',
                                   web_endpoint: 'http://my-openbis.org/openbis',
                                   as_endpoint: 'http://my-openbis.org/openbis',
                                   dss_endpoint: 'http://my-openbis.org/openbis',
                                   space_perm_id: 'mmmm'

    assert endpoint.valid?
    endpoint.username=nil
    refute endpoint.valid?
    endpoint.username='fred'
    assert endpoint.valid?

    endpoint.password=nil
    refute endpoint.valid?
    endpoint.password='12345'
    assert endpoint.valid?

    endpoint.space_perm_id=nil
    refute endpoint.valid?
    endpoint.space_perm_id='mmmmm'
    assert endpoint.valid?

    endpoint.as_endpoint=nil
    refute endpoint.valid?
    endpoint.as_endpoint='fish'
    refute endpoint.valid?
    endpoint.as_endpoint='http://my-openbis.org/openbis'
    assert endpoint.valid?

    endpoint.dss_endpoint=nil
    refute endpoint.valid?
    endpoint.dss_endpoint='fish'
    refute endpoint.valid?
    endpoint.dss_endpoint='http://my-openbis.org/openbis'
    assert endpoint.valid?

    endpoint.web_endpoint=nil
    refute endpoint.valid?
    endpoint.web_endpoint='fish'
    refute endpoint.valid?
    endpoint.web_endpoint='http://my-openbis.org/openbis'
    assert endpoint.valid?

    endpoint.project=nil
    refute endpoint.valid?
    endpoint.project=Factory(:project)
    assert endpoint.valid?
  end

  test 'validates uniqueness' do
    endpoint = Factory(:openbis_endpoint)
    endpoint2 = Factory.build(:openbis_endpoint)
    assert endpoint.valid? #different project
    endpoint2 = Factory.build(:openbis_endpoint,project:endpoint.project)
    refute endpoint2.valid?
    endpoint2.as_endpoint='http://fish.com'
    assert endpoint2.valid?
    endpoint2.as_endpoint=endpoint.as_endpoint
    refute endpoint2.valid?
    endpoint2.dss_endpoint='http://fish.com'
    assert endpoint2.valid?
  end

  test 'link to project' do
    pa=Factory(:project_administrator)
    project=pa.projects.first
    User.with_current_user(pa.user) do
      with_config_value :openbis_enabled,true do
        endpoint = OpenbisEndpoint.create project:project, username:'fred', password:'12345', as_endpoint:'http://my-openbis.org/openbis', dss_endpoint:'http://my-openbis.org/openbis',web_endpoint:'http://my-openbis.org/openbis', space_perm_id:'aaa'
        endpoint2 = OpenbisEndpoint.create project:project, username:'fred', password:'12345', as_endpoint:'http://my-openbis.org/openbis', dss_endpoint:'http://my-openbis.org/openbis',web_endpoint:'http://my-openbis.org/openbis', space_perm_id:'bbb'
        endpoint.save!
        endpoint2.save!
        project.reload
        assert_equal [endpoint,endpoint2].sort,project.openbis_endpoints.sort
      end
    end
  end

  test 'can_create' do
    User.with_current_user(Factory(:project_administrator).user) do
      with_config_value :openbis_enabled,true do
        assert OpenbisEndpoint.can_create?
      end

      with_config_value :openbis_enabled,false do
        refute OpenbisEndpoint.can_create?
      end
    end

    User.with_current_user(Factory(:person).user) do
      with_config_value :openbis_enabled,true do
        refute OpenbisEndpoint.can_create?
      end

      with_config_value :openbis_enabled,false do
        refute OpenbisEndpoint.can_create?
      end
    end

    User.with_current_user(nil) do
      with_config_value :openbis_enabled,true do
        refute OpenbisEndpoint.can_create?
      end

      with_config_value :openbis_enabled,false do
        refute OpenbisEndpoint.can_create?
      end
    end
  end

  test 'can_delete?' do

    person = Factory(:person)
    ep = Factory(:openbis_endpoint,project:person.projects.first)
    refute ep.can_delete?(person.user)
    User.with_current_user(person.user) do
      refute ep.can_delete?
    end

    pa = Factory(:project_administrator)
    ep = Factory(:openbis_endpoint,project:pa.projects.first)
    assert ep.can_delete?(pa.user)
    User.with_current_user(pa.user) do
      assert ep.can_delete?
    end

    another_pa = Factory(:project_administrator)
    refute ep.can_delete?(another_pa.user)
    User.with_current_user(another_pa.user) do
      refute ep.can_delete?
    end

    #cannot delete if linked
    #first check another linked endpoint doesn't prevent delete
    refute_nil openbis_linked_content_blob("20160210130454955-23")
    assert ep.can_delete?(pa.user)
    User.with_current_user(pa.user) do
      assert ep.can_delete?
    end

    refute_nil openbis_linked_content_blob("20160210130454955-23",ep)
    refute ep.can_delete?(pa.user)
    User.with_current_user(pa.user) do
      refute ep.can_delete?
    end

  end

  test 'available spaces' do
    endpoint = Factory(:openbis_endpoint)
    spaces = endpoint.available_spaces
    assert_equal 2,spaces.count
  end

  test 'space' do
    endpoint = Factory(:openbis_endpoint)
    space = endpoint.space
    refute_nil space
    assert_equal 'API-SPACE',space.perm_id
  end


  test 'can edit?' do
    pa=Factory(:project_administrator).user
    user=Factory(:person).user
    endpoint = OpenbisEndpoint.create project:pa.person.projects.first, username:'fred', password:'12345', as_endpoint:'http://my-openbis.org/openbis', dss_endpoint:'http://my-openbis.org/openbis', space_perm_id:'aaa'
    User.with_current_user(pa) do
      with_config_value :openbis_enabled,true do
        assert endpoint.can_edit?
      end

      with_config_value :openbis_enabled,false do
        refute endpoint.can_edit?
      end
    end

    User.with_current_user(user) do
      with_config_value :openbis_enabled,true do
        refute endpoint.can_edit?
      end

      with_config_value :openbis_enabled,false do
        refute endpoint.can_edit?
      end
    end

    User.with_current_user(nil) do
      with_config_value :openbis_enabled,true do
        refute endpoint.can_edit?
      end

      with_config_value :openbis_enabled,false do
        refute endpoint.can_edit?
      end
    end

    with_config_value :openbis_enabled,true do
      assert endpoint.can_edit?(pa)
      refute endpoint.can_edit?(user)
      refute endpoint.can_edit?(nil)

      #cannot edit if another project admin
      pa2=Factory(:project_administrator).user
      refute endpoint.can_edit?(pa2)

    end
  end

  test 'session token' do
    endpoint = Factory(:openbis_endpoint)

    refute_nil endpoint.session_token
  end

  test 'cache key' do
    endpoint = OpenbisEndpoint.new username:'fred', password:'12345', as_endpoint:'http://my-openbis.org/openbis', dss_endpoint:'http://my-openbis.org/openbis', space_perm_id:'aaa'
    assert_equal 'openbis_endpoints/new-ddf17b57f57098ff63383825125f00089a1e1c1cc4de18b27e30e3b9642854a9',endpoint.cache_key
    endpoint.space_perm_id='bbb'
    assert_equal 'openbis_endpoints/new-867be42425f47d36cc6b91926853a714251da75cea9c7517046e610d2f0201ca',endpoint.cache_key

    endpoint = Factory(:openbis_endpoint)
    assert_equal "openbis_endpoints/#{endpoint.id}-#{endpoint.updated_at.utc.to_s(:number)}",endpoint.cache_key
  end

  test 'destroy' do
    pa = Factory(:project_administrator)
    endpoint = Factory(:openbis_endpoint,project:pa.projects.first)
    key = endpoint.space.cache_key(endpoint.space_perm_id)
    assert Rails.cache.exist?(key)
    assert_difference('OpenbisEndpoint.count',-1) do
      User.with_current_user(pa.user) do
        endpoint.destroy
      end
    end
    refute Rails.cache.exist?(key)
  end

  test 'clear cache' do
    endpoint = Factory(:openbis_endpoint)
    key = endpoint.space.cache_key(endpoint.space_perm_id)
    assert Rails.cache.exist?(key)
    endpoint.clear_cache
    refute Rails.cache.exist?(key)
  end

  test 'create_refresh_cache_job' do
    endpoint=Factory(:openbis_endpoint)
    Delayed::Job.destroy_all
    refute OpenbisEndpointCacheRefreshJob.new(endpoint).exists?
    assert_difference('Delayed::Job.count',1) do
      endpoint.create_refresh_cache_job
    end
    assert_no_difference('Delayed::Job.count') do
      endpoint.create_refresh_cache_job
    end
    assert OpenbisEndpointCacheRefreshJob.new(endpoint).exists?

  end

  test 'create job on creation' do
    Delayed::Job.destroy_all
    endpoint=Factory(:openbis_endpoint)
    assert OpenbisEndpointCacheRefreshJob.new(endpoint).exists?
  end

  test 'job destroyed on delete' do
    Delayed::Job.destroy_all
    pa = Factory(:project_administrator)
    endpoint = Factory(:openbis_endpoint,project:pa.projects.first)
    assert_difference('Delayed::Job.count',-1) do
      User.with_current_user(pa.user) do
        endpoint.destroy
      end
    end
    refute OpenbisEndpointCacheRefreshJob.new(endpoint).exists?
  end

end