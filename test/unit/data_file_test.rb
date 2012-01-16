require 'test_helper'

class DataFileTest < ActiveSupport::TestCase

  fixtures :all

  test "associations" do
    datafile_owner = Factory :user
    datafile=Factory :data_file,:policy => Factory(:all_sysmo_viewable_policy),:contributor=> datafile_owner
    assert_equal datafile_owner,datafile.contributor
    unless datafile.content_blob.nil?
      datafile.content_blob = nil
    end

    blob=Factory.create(:content_blob,:original_filename=>"df.ppt", :content_type=>"application/ppt",:asset => datafile,:asset_version=>datafile.version)#content_blobs(:picture_blob)
    assert_equal blob,datafile.content_blob
  end

  test "event association" do
    User.with_current_user Factory(:user) do
      datafile = Factory :data_file, :contributor => User.current_user
      event = Factory :event, :contributor => User.current_user
      datafile.events << event
      assert datafile.valid?
      assert datafile.save
      assert_equal 1, datafile.events.count
    end
  end

  test "assay association" do
    User.with_current_user Factory(:user) do
      datafile = Factory :data_file,:policy => Factory(:all_sysmo_viewable_policy)
      assay = assays(:modelling_assay_with_data_and_relationship)
      relationship = relationship_types(:validation_data)
      assay_asset = assay_assets(:metabolomics_assay_asset1)
      assert_not_equal assay_asset.asset, datafile
      assert_not_equal assay_asset.assay, assay
      assay_asset.asset = datafile
      assay_asset.assay = assay
      assay_asset.relationship_type = relationship
      assay_asset.save!
      assay_asset.reload

      assert assay_asset.valid?
      assert_equal assay_asset.asset, datafile
      assert_equal assay_asset.assay, assay
      assert_equal assay_asset.relationship_type, relationship
    end
  end

  test "sort by updated_at" do
    assert_equal DataFile.find(:all).sort_by { |df| df.updated_at.to_i * -1 }, DataFile.find(:all)
  end

  test "validation" do
    asset=DataFile.new :title=>"fred",:projects=>[projects(:sysmo_project)]
    assert asset.valid?

    asset=DataFile.new :projects=>[projects(:sysmo_project)]
    assert !asset.valid?

    #VL only:allow no projects
    asset=DataFile.new :title=>"fred"
    assert asset.valid?


    asset = DataFile.new :title => "fred", :projects => []
    assert asset.valid?
  end

  def test_avatar_key

    assert_nil data_files(:picture).avatar_key
    assert data_files(:picture).use_mime_type_for_avatar?

    assert_nil data_file_versions(:picture_v1).avatar_key
    assert data_file_versions(:picture_v1).use_mime_type_for_avatar?
  end

  test "projects" do
    df=data_files(:sysmo_data_file)
    p=projects(:sysmo_project)
    assert_equal [p],df.projects
    assert_equal [p],df.latest_version.projects
  end
  
  def test_defaults_to_private_policy
    df_hash = Factory.attributes_for(:data_file)
    df_hash[:policy] = nil
    df=DataFile.new(df_hash)
    df.save!
    df.reload
    assert_not_nil df.policy
    assert_equal Policy::PRIVATE, df.policy.sharing_scope
    assert_equal Policy::NO_ACCESS, df.policy.access_type
    assert_equal false,df.policy.use_whitelist
    assert_equal false,df.policy.use_blacklist
    assert df.policy.permissions.empty?
  end

  test "data_file with no contributor" do
    df=data_files(:data_file_with_no_contributor)
    assert_nil df.contributor
  end

  test "versions destroyed as dependent" do
    df=data_files(:sysmo_data_file)
    User.current_user = df.contributor
    assert_equal 1,df.versions.size,"There should be 1 version of this DataFile"
    assert_difference(["DataFile.count","DataFile::Version.count"],-1) do
      df.destroy
    end
  end

  test "managers" do
    df= data_files(:picture)
    assert_not_nil df.managers
    contributor= people(:person_for_datafile_owner)
    manager=people(:person_for_owner_of_my_first_sop)
    assert df.managers.include?(contributor)
    assert df.managers.include?(manager)
    assert !df.managers.include?(people(:person_not_associated_with_any_projects))
  end

  test "make sure content blob is preserved after deletion" do
    df = Factory :data_file #data_files(:picture)
    User.current_user = df.contributor
    assert_not_nil df.content_blob,"Must have an associated content blob for this test to work"
    cb=df.content_blob
    assert_difference("DataFile.count",-1) do
      assert_no_difference("ContentBlob.count") do
        df.destroy
      end
    end
    assert_not_nil ContentBlob.find(cb.id)
  end

  test "is restorable after destroy" do
    df = Factory :data_file,:policy => Factory(:all_sysmo_viewable_policy)
    User.current_user = df.contributor
    assert_difference("DataFile.count",-1) do
      df.destroy
    end
    assert_nil DataFile.find_by_id(df.id)
    assert_difference("DataFile.count",1) do
      disable_authorization_checks {DataFile.restore_trash!(df.id)}
    end
    assert_not_nil DataFile.find_by_id(df.id)
  end

  test 'failing to delete due to can_delete does not create trash' do
    df = Factory :data_file, :policy => Factory(:private_policy), :contributor => Factory(:user)
    User.with_current_user Factory(:user) do
      assert_no_difference("DataFile.count") do
        df.destroy
      end
      assert_nil DataFile.restore_trash(df.id)
    end
  end
  
  test "test uuid generated" do
    x = data_files(:picture)
    assert_nil x.attributes["uuid"]
    x.save
    assert_not_nil x.attributes["uuid"]
  end
  
  test "title_trimmed" do
    df= Factory :data_file ,:policy=>Factory(:policy,:sharing_scope=>Policy::ALL_SYSMO_USERS,:access_type=>Policy::EDITING) #data_files(:picture)
    df.title=" should be trimmed"
    df.save!
    assert_equal "should be trimmed",df.title
  end

  test "uuid doesn't change" do
    x = Factory :data_file,:policy => Factory(:all_sysmo_viewable_policy)#data_files(:picture)
    x.save
    uuid = x.attributes["uuid"]
    x.save
    assert_equal x.uuid, uuid
  end
  
  test "can get relationship type" do
    df = data_file_versions(:picture_v1)
    assay = assays(:modelling_assay_with_data_and_relationship)
    assert_equal relationship_types(:validation_data), df.relationship_type(assay)
  end

  test "delete checks authorization" do
    df = Factory :data_file

    User.current_user = nil
    assert !df.destroy

    User.current_user = df.contributor
    assert df.destroy
  end

  test 'update checks authorization' do
    unupdated_title = "Unupdated Title"
    df = Factory :data_file, :title => unupdated_title
    User.current_user = nil

    assert !df.update_attributes(:title => "Updated Title")
    assert_equal unupdated_title, df.reload.title
  end

  test "convert to presentation" do
    user = Factory :user
    attribution_df = Factory :data_file
    User.with_current_user(user) {
      data_file = Factory :data_file,:contributor=>user,:version=>2,
                          :assay_ids=>[Factory(:modelling_assay).id,Factory(:experimental_assay).id]
      Factory :content_blob,:asset=>data_file
      Factory :attribution,:subject=>data_file,:object=>attribution_df
      Factory :relationship,:subject=>data_file,:object=>Factory(:publication),:predicate=>Relationship::RELATED_TO_PUBLICATION
      data_file.creators = [Factory(:person),Factory(:person)]
      Factory :annotation,:attribute_name=>"tags",:annotatable=> data_file,:attribute_id => AnnotationAttribute.create(:name=>"tags").id
      data_file.events = [Factory(:event)]
      Factory :scaling, :person=> Factory(:person),:scalable=>data_file, :scale => Factory(:scale)
      data_file.save!

      data_file.reload

      #I want to compare data_file.scales to data_file_converted.scales later. If I don't load data_file.scales now,
      #then it will try to load them when I do the comparison. Since that will be after I've updated the database from converting, it would return [].
      #to avoid this, I will preload scales and similar through_associations now.
      through_associations_to_test_later = [:scales, :creators, :assays]
      through_associations_to_test_later.each {|a| data_file.send(a).send(:load_target)}

      presentation = Factory.build :presentation,:contributor=>user

      data_file_converted = data_file.to_presentation!
      data_file_converted = data_file_converted.reload

      assert_equal presentation.class.name, data_file_converted.class.name
      assert_equal presentation.attributes.keys.sort!, data_file_converted.attributes.keys.reject{|k|k=='id'}.sort! #???

      #data_file.reload
      #data file still has some associations that are assigned to data_file_converted, as it is NOT reloaded
      assert_equal data_file.version, data_file_converted.version
      assert_equal data_file.policy.sharing_scope, data_file_converted.policy.sharing_scope
      assert_equal data_file.policy.access_type, data_file_converted.policy.access_type
      assert_equal data_file.policy.use_whitelist, data_file_converted.policy.use_whitelist
      assert_equal data_file.policy.use_blacklist, data_file_converted.policy.use_blacklist
      assert_equal data_file.policy.permissions, data_file_converted.policy.permissions
      assert data_file.policy.id != data_file_converted.policy.id
      assert_equal data_file.content_blob, data_file_converted.content_blob

      assert_equal data_file.subscriptions.map(&:person_id), data_file_converted.subscriptions(&:person_id)
      assert_equal data_file.projects,data_file_converted.projects
      assert_equal data_file.attributions , data_file_converted.attributions
      assert_equal data_file.related_publications, data_file_converted.related_publications
      assert_equal data_file.creators, data_file_converted.creators
      assert_equal data_file.annotations, data_file_converted.annotations
      assert_equal data_file.project_ids,data_file_converted.project_ids
      assert_equal data_file.assays,data_file_converted.assays
      assert_equal data_file.event_ids, data_file_converted.event_ids
      assert_equal data_file.scalings,data_file_converted.scalings
      assert_equal data_file.scales,data_file_converted.scales
      assert_equal data_file.versions.map(&:updated_at).sort, data_file_converted.versions.map(&:updated_at).sort
    }
  end

  test "fs_search_fields" do
    user = Factory :user
    User.with_current_user user do
      df = Factory :data_file,:contributor=>user
      sf1 = Factory :studied_factor_link,:substance=>Factory(:compound,:name=>"sugar")
      sf2 = Factory :studied_factor_link,:substance=>Factory(:compound,:name=>"iron")
      comp=sf2.substance
      Factory :synonym,:name=>"metal",:substance=>comp
      Factory :mapping_link,:substance=>comp,:mapping=>Factory(:mapping,:chebi_id=>"12345",:kegg_id=>"789",:sabiork_id=>111)
      studied_factor = Factory :studied_factor,:studied_factor_links=>[sf1,sf2],:data_file=>df
      assert df.fs_search_fields.include?("sugar")
      assert df.fs_search_fields.include?("metal")
      assert df.fs_search_fields.include?("iron")
      assert df.fs_search_fields.include?("concentration")
      assert df.fs_search_fields.include?("CHEBI:12345")
      assert df.fs_search_fields.include?("12345")
      assert df.fs_search_fields.include?("111")
      assert df.fs_search_fields.include?("789")
      assert_equal 8,df.fs_search_fields.count
    end
  end

  test "fs_search_fields_with_synonym_substance" do
    user = Factory :user
    User.with_current_user user do
      df = Factory :data_file,:contributor=>user
      suger = Factory(:compound,:name=>"sugar")
      iron = Factory(:compound,:name=>"iron")
      metal = Factory :synonym,:name=>"metal",:substance=>iron
      Factory :mapping_link,:substance=>iron,:mapping=>Factory(:mapping,:chebi_id=>"12345",:kegg_id=>"789",:sabiork_id=>111)
      
      sf1 = Factory :studied_factor_link,:substance=>suger
      sf2 = Factory :studied_factor_link, :substance=>metal



      Factory :studied_factor,:studied_factor_links=>[sf1,sf2],:data_file=>df
      assert df.fs_search_fields.include?("sugar")
      assert df.fs_search_fields.include?("metal")
      assert df.fs_search_fields.include?("iron")
      assert df.fs_search_fields.include?("concentration")
      assert df.fs_search_fields.include?("CHEBI:12345")
      assert df.fs_search_fields.include?("12345")
      assert df.fs_search_fields.include?("111")
      assert df.fs_search_fields.include?("789")
      assert_equal 8,df.fs_search_fields.count
    end
  end
  
end
