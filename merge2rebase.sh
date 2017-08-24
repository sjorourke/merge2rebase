function m2r {

  function _unset_vars {
    unset _commit_hash_array
    unset _curr_commit_hash
    unset _input
    unset _last_commit_element_index
    unset _last_merge_element_index
    unset _merge_hash_array
    unset _merge_parent_array
    unset _merge_parent_hash
    unset _new_branch_name
    unset _orig_branch_name
    unset _parent_branch_name
    unset -f _continue
    unset -f _unset_vars
  }

  function _prep_for_continue {
    git checkout $1 $(git ls-files -u | cut -f 2 | sort -u) # http://stackoverflow.com/questions/307579/how-do-i-copy-a-version-of-a-single-file-from-one-git-branch-to-another
    git add -A
    git commit -am "merge2rebase - $2" --allow-empty
  }

  _orig_branch_name=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p') # http://stackoverflow.com/questions/2111042/how-to-get-the-name-of-the-current-git-branch-into-a-variable-in-a-shell-script
  _new_branch_name="${_orig_branch_name}_aux"
  git checkout -b "$_new_branch_name" || { _unset_vars; return; }
  git log -n 1
  echo -n "Include this commit? (enter to continue): "
  read _input
  _commit_hash_array=()
  _merge_hash_array=()
  _last_commit_element_index=-1
  _last_merge_element_index=-1
  while [[ $_input == "" ]]; do
    _curr_commit_hash="$(git log -n 1 --pretty=format:'%H')"
    _commit_hash_array+=($_curr_commit_hash) # http://stackoverflow.com/questions/949314/how-to-retrieve-the-hash-for-the-current-commit-in-git
    ((_last_commit_element_index++))
    if [[ $(git log --pretty=%P -n 1 $_curr_commit_hash) =~ ' ' ]]; then # http://stackoverflow.com/questions/9059335/get-parents-of-a-merge-commit-in-git
      _merge_hash_array+=( "$(git rev-parse $_curr_commit_hash^2)" ) # http://stackoverflow.com/questions/9059335/get-parents-of-a-merge-commit-in-git
      _merge_parent_array+=( $(sed "s/ branch / /g;s/[\'\"]//g;s/ into $_orig_branch_name$//;s/^[mM]erge //" <<< $(git log --format=%B -n 1 $_curr_commit_hash)) )
      ((_last_merge_element_index++))
    fi
    git reset HEAD~1
    git clean -fd
    git checkout -- .
    git log -n 1
    echo "Continue?"
    echo -n "If you recognize this commit, hit enter to continue, or submit any character(s) to stop: "
    read _input
  done

  if [[ $1 ]] && [[ $1 == * ]]; then
    while [[ $_last_merge_element_index > -1 ]]; do
      _curr_merge_hash="${_merge_hash_array[((_last_merge_element_index))]}"
      _parent_branch_name=${_merge_parent_array[((_last_merge_element_index))]}
      git checkout $_parent_branch_name
      git pull origin $_parent_branch_name
      git checkout -b ${_parent_branch_name}_aux
      git reset --hard $_curr_merge_hash
      git checkout $_new_branch_name
      git merge $_parent_branch_name --edit "merge2rebase - $_orig_branch_name"
      if [[ $(git ls-files -u | cut -f 2 | sort -u) != '' ]]; then # http://stackoverflow.com/questions/3065650/whats-the-simplest-way-to-get-a-list-of-conflicted-files
        _prep_for_continue $_curr_commit_hash $_orig_branch_name
      fi
      git branch -D ${_parent_branch_name}_aux
      ((_last_merge_element_index--))
    done
    while [[ $_last_commit_element_index > -1 ]]; do
      _curr_commit_hash="${_commit_hash_array[((_last_commit_element_index))]}"
      if ! [[ $(git log --pretty=%P -n 1 $_curr_commit_hash) =~ ' ' ]]; then # http://stackoverflow.com/questions/9059335/get-parents-of-a-merge-commit-in-git
        git cherry-pick $_curr_commit_hash
        if [[ $(git ls-files -u | cut -f 2 | sort -u) != '' ]]; then # http://stackoverflow.com/questions/3065650/whats-the-simplest-way-to-get-a-list-of-conflicted-files
          _prep_for_continue $_curr_commit_hash $_orig_branch_name
        fi
      fi
      ((_last_commit_element_index--))
    done
  else
    if [[ $1 ]]; then
      _parent_branch_name="$1"
    else
      _parent_branch_name="master"
    fi
    while [[ $_last_commit_element_index > -1 ]]; do
      _curr_commit_hash="${_commit_hash_array[((_last_commit_element_index))]}"
      if [[ $(git log --pretty=%P -n 1 $_curr_commit_hash) =~ ' ' ]]; then # http://stackoverflow.com/questions/9059335/get-parents-of-a-merge-commit-in-git
        git checkout $_parent_branch_name
        git pull origin $_parent_branch_name
        git checkout -b ${_parent_branch_name}_aux
        git reset --hard $(git rev-parse $_curr_commit_hash^2) # http://stackoverflow.com/questions/9059335/get-parents-of-a-merge-commit-in-git
        git checkout $_new_branch_name
        git rebase ${_parent_branch_name}_aux $_new_branch_name
        while [[ $(git ls-files -u | cut -f 2 | sort -u) != '' ]]; do # http://stackoverflow.com/questions/3065650/whats-the-simplest-way-to-get-a-list-of-conflicted-files
          _prep_for_continue $_curr_commit_hash $_orig_branch_name
          git rebase --skip # http://stackoverflow.com/questions/14410421/git-rebase-merge-conflict-cannot-continue
        done
        git branch -D ${_parent_branch_name}_aux
      else
        git cherry-pick $_curr_commit_hash
        if [[ $(git ls-files -u | cut -f 2 | sort -u) != '' ]]; then # http://stackoverflow.com/questions/3065650/whats-the-simplest-way-to-get-a-list-of-conflicted-files
          _prep_for_continue $_curr_commit_hash $_orig_branch_name
        fi
      fi
      ((_last_commit_element_index--))
    done
  fi

  _unset_vars
}
