module Projects
  class UpdateService < BaseService
    def execute
      # check that user is allowed to set specified visibility_level
      new_visibility = params[:visibility_level]

      if new_visibility && new_visibility.to_i != project.visibility_level
        unless can?(current_user, :change_visibility_level, project) &&
            Gitlab::VisibilityLevel.allowed_for?(current_user, new_visibility)

          deny_visibility_level(project, new_visibility)
          return error('Visibility level unallowed')
        end
      end

      new_branch = params[:default_branch]

      if project.repository.exists? && new_branch && new_branch != project.default_branch
        project.change_head(new_branch)
      end

      project.assign_attributes(params.except(:default_branch))

      if project.renamed? && !project.can_create_repository?
        return error('Cannot rename project because there is already a repository with that new name on disk')
      end

      if project.save
        if project.previous_changes.include?('path')
          project.rename_repo
        else
          system_hook_service.execute_hooks_for(project, :update)
        end

        success
      else
        error('Project could not be updated')
      end
    end
  end
end
