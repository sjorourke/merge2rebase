function m2r {

  function _unset_vars {
    unset _commit_hash_array
    unset _curr_commit_hash
    unset _input
    unset _last_element_index
    unset _new_branch_name
    unset _orig_branch_name
    unset -f _unset_vars
  }

  _orig_branch_name=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p') # http://stackoverflow.com/questions/2111042/how-to-get-the-name-of-the-current-git-branch-into-a-variable-in-a-shell-script
  _new_branch_name="${_orig_branch_name}_aux"
  git checkout -b "$_new_branch_name" || { _unset_vars; return; }
  git log -n 1
  echo -n "Include this commit? (enter to continue): "
  read _input
  _commit_hash_array=()
  _last_element_index=-1
  while [[ $_input == "" ]]; do
    _commit_hash_array+=("$(git log -n 1 --pretty=format:'%H')") # http://stackoverflow.com/questions/949314/how-to-retrieve-the-hash-for-the-current-commit-in-git
    ((_last_element_index++))
    git reset HEAD~1
    git clean -fd
    git checkout -- .
    git log -n 1
    echo "Continue?"
    echo -n "If you recognize this commit, hit enter to continue, or submit any characters(s) to stop: "
    read _input
  done
  while [[ $_last_element_index > -1 ]]; do
    _curr_commit_hash="${_commit_hash_array[((_last_element_index))]}"
    if [[ $(git log --pretty=%P -n 1 $_curr_commit_hash) =~ ' ' ]]; then # http://stackoverflow.com/questions/9059335/get-parents-of-a-merge-commit-in-git
      git checkout master
      git pull origin master
      git checkout -b master_aux
      git reset --hard $(git rev-parse $_curr_commit_hash^2) # http://stackoverflow.com/questions/9059335/get-parents-of-a-merge-commit-in-git
      git checkout $_new_branch_name
      git rebase master_aux $_new_branch_name
      while [[ $(git ls-files -u | cut -f 2 | sort -u) != '' ]]; do # http://stackoverflow.com/questions/3065650/whats-the-simplest-way-to-get-a-list-of-conflicted-files
        git checkout $_curr_commit_hash $(git ls-files -u | cut -f 2 | sort -u) # http://stackoverflow.com/questions/307579/how-do-i-copy-a-version-of-a-single-file-from-one-git-branch-to-another
        git add -A
        git commit -am "merge2rebase - $_orig_branch_name"
        git rebase --skip # http://stackoverflow.com/questions/14410421/git-rebase-merge-conflict-cannot-continue
      done
      git branch -D master_aux
    else
      git cherry-pick $_curr_commit_hash
    fi
    ((_last_element_index--))
  done
}
