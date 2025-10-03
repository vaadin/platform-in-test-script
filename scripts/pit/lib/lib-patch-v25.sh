


applyv25patches() {
  app_=$1; type_=$2; vers_=$3
  [ -d src/main ] && D=src/main || D=*/src/main
  F=$D/frontend

  changeMavenBlock parent org.springframework.boot spring-boot-starter-parent 4.0.0-M3
  addAnonymousAllowedToAppLayout
  updateAppLayoutAfterNavigation

  diff_=`git diff $D $F | egrep '^[+-]'`
  [ -n "$diff_" ] && echo "" && warn "Patched sources\n" && dim "====== BEGIN ======\n\n$diff_\n======  END  ======"

  return 0
}

## Find all java class files that extend AppLayout and have afterNavigation() method, then update them to implement AfterNavigationObserver
## This break change is in https://github.com/vaadin/flow-components/issues/5449
## TODO: needs to be documented in vaadin migration guide to 25
updateAppLayoutAfterNavigation() {
  find src -name "*.java" -exec grep -l "extends AppLayout" {} + | xargs grep -L "extends AppLayoutElement" | while read file; do
    # Check if the file contains afterNavigation method
    if grep -q "afterNavigation()" "$file"; then
      warn "updating afterNavigation method in $file"
      
      # Check if already implements AfterNavigationObserver
      if ! grep -q "implements.*AfterNavigationObserver" "$file"; then
        # Add implements AfterNavigationObserver to class declaration
        perl -pi -e 's/(public\s+class\s+[A-Za-z0-9_]+\s+extends\s+AppLayout)(\s*)(\{)/$1 implements com.vaadin.flow.router.AfterNavigationObserver$2$3/' "$file"
      fi
      
      # Transform the method - handle both with and without @Override in one pattern
      perl -0777 -pi -e 's/(\s+)(?:@Override\s+)?protected\s+void\s+afterNavigation\(\)\s*\{\s*super\.afterNavigation\(\);\s*/$1@Override\n$1public void afterNavigation(com.vaadin.flow.router.AfterNavigationEvent event) {\n$1/gs' "$file"
    fi
  done
}