class WorkflowSerializer < ContributedResourceSerializer
  attribute :workflow_class do
    {
        title: object.workflow_class.title,
        key: object.workflow_class.key,
        description: object.workflow_class.description
    }
  end

  has_many :people
  has_many :projects
  has_many :investigations
  has_many :studies
  has_many :assays
  has_many :publications
  has_many :sops

  def _links
    if get_version.diagram.exists?
      super.merge(diagram: diagram_workflow_path(object, version: get_version.version))
    else
      super
    end
  end
end
