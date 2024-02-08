
applyv244Patches() {
  app_=$1; type_=$2; vers_=$3
  [ -d frontend ] && F=frontend || F=*/frontend
  [ -d src/main ] && D=src/main || D=*/src/main

  case $app_ in
      *-lit|*-lit-*|*-lit_*)
        patchLitV244
        patchHillaSourcesV244 $D $F
        rm -f types.d.ts package-lock.json
      ;;
  esac

  diff_=`git diff $D $F | egrep '^[+-]'`
  [ -n "$diff_" ] && echo "" && warn "Patched sources\n" && dim "====== BEGIN ======\n\n$diff_\n======  END  ======" || true
}

patchHillaSourcesV244() {
  find $D -name "*.java" -exec perl -pi -e 's/import dev.hilla/import com.vaadin.hilla/g' '{}' ';'
  find $F -name "*.ts" -exec perl -pi -e 's|\@hilla/form|\@vaadin/hilla-lit-form|g' '{}' ';'
  find $F -name "*.ts" -exec perl -pi -e 's|Frontend/generated/dev/hilla|Frontend/generated/com/vaadin/hilla|g' '{}' ';'
  find $F -name "*.ts" -exec perl -pi -e 's|\@hilla/frontend|\@vaadin/hilla-core|g' '{}' ';'
  find $F -name "*.tsx" -exec perl -pi -e 's|\@hilla/frontend|\@vaadin/hilla-core|g' '{}' ';'
  find $F -name "*.tsx" -exec perl -pi -e 's|\@hilla/react-form|\@vaadin/hilla-react-form|g' '{}' ';'
  find $F -name "*.ts" -exec perl -pi -e 's|\@hilla/|\@vaadin/|g' '{}' ';'
  find $F -name "*.tsx" -exec perl -pi -e 's|\@hilla/|\@vaadin/|g' '{}' ';'
}


patchLitV244() {
  renameMavenProperty hilla.version vaadin.version
  changeMavenBlock dependency dev.hilla hilla "\\\${vaadin.version}" com.vaadin vaadin
  changeMavenBlock dependency dev.hilla hilla-bom "\\\${vaadin.version}" com.vaadin vaadin-bom
  changeMavenBlock dependency dev.hilla hilla-spring-boot-starter "\\\${vaadin.version}" com.vaadin vaadin-spring-boot-starter
  changeMavenBlock plugin dev.hilla hilla-maven-plugin "\\\${vaadin.version}" com.vaadin vaadin-maven-plugin
  perl -pi -e "s|(\s+)(<artifactId>vaadin-maven-plugin</artifactId>)|\$1\$2\n\$1<configuration><reactRouterEnabled>false</reactRouterEnabled></configuration>|g" pom.xml
}

