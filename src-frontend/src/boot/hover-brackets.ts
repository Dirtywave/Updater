import { bracketsDirective } from 'directives/hover-brackets';
import { defineBoot } from 'boot/types';

export default defineBoot(({ app }) => {
  app.directive('brackets', bracketsDirective);
});
